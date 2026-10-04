import SwiftUI
import FusionhaKit

/// Settings → Logs (`LogsPanel.tsx`): a live tail of the backend's log ring
/// buffer — level floor + keyword filter (client-side, instant), Auto-scroll,
/// LIVE / Paused, Download (share sheet) and Clear; error rows expand their
/// traceback.
struct LogsPanel: View {
    enum Floor: String, CaseIterable, Identifiable {
        case all = "ALL", debug = "DEBUG", info = "INFO", warning = "WARNING", error = "ERROR"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: "All"
            case .debug: "Debug"
            case .info: "Info"
            case .warning: "Warn"
            case .error: "Error"
            }
        }
    }

    static let levels = ["DEBUG", "INFO", "WARNING", "ERROR"]
    static let maxRecords = 2000

    @Environment(AppModel.self) private var model
    @Environment(\.settingsMotionOff) private var motionOff
    @Environment(\.scenePhase) private var scenePhase
    @State private var records: [LogRecord] = []
    @State private var since: Double?
    @State private var failed = false
    @State private var live = true
    @State private var autoScroll = true
    @State private var floor: Floor = .all
    @State private var keyword = ""
    @State private var downloading = false
    @State private var shareItem: FetchShareItem?
    @State private var toaster = FetchToaster()
    @State private var confirm: FetchConfirm?

    private var filtered: [LogRecord] {
        let min = floor == .all ? -1 : Self.rank(floor.rawValue)
        let needle = keyword.trimmingCharacters(in: .whitespaces).lowercased()
        return records.filter { record in
            if Self.rank(record.level) < min { return false }
            if !needle.isEmpty, !"\(record.message) \(record.logger)".lowercased().contains(needle) { return false }
            return true
        }
    }

    var body: some View {
        FetchingPage(slug: "logs", toaster: toaster, confirm: $confirm, refresh: { await poll() }) {
            VStack(alignment: .leading, spacing: 12) {
                toolbar.fetchReveal(0)
                if failed {
                    Text("Couldn’t reach the log stream — retrying…")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.danger)
                        .accessibilityAddTraits(.updatesFrequently)
                        .transition(.opacity)
                }
                viewport.fetchReveal(1)
            }
        }
        .task(id: live) { await tail() }
        .sheet(item: $shareItem) { item in
            FetchActivityView(url: item.url)
                .presentationDetents([.medium, .large])
                .ignoresSafeArea()
        }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Log level", selection: $floor) {
                ForEach(Floor.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 13)).foregroundStyle(Theme.dim)
                TextField("Filter logs", text: $keyword, prompt: Text("Filter by message or source…").foregroundStyle(Theme.dim))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.txt)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                if !keyword.isEmpty {
                    Button { keyword = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.dim)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear filter")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous).strokeBorder(Theme.line))

            HStack(spacing: 10) {
                Toggle(isOn: $autoScroll) {
                    Text("Auto-scroll").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.mut)
                }
                .toggleStyle(.switch)
                .tint(Theme.cyan)
                .fixedSize()
                Spacer(minLength: 4)
                Button { live.toggle() } label: {
                    HStack(spacing: 6) {
                        LiveDot(live: live)
                        Text(live ? "LIVE" : "Paused")
                    }
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(live ? Theme.grab : Theme.mut)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(live ? Theme.grab.opacity(0.12) : Theme.card, in: Capsule())
                    .overlay(Capsule().strokeBorder(live ? Theme.grab.opacity(0.4) : Theme.line))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(live ? .isSelected : [])
                Button(action: download) {
                    if downloading { ProgressView().controlSize(.mini) } else { Text("Download") }
                }
                .buttonStyle(.web(.subtle))
                .disabled(downloading)
                Button("Clear", action: clear)
                    .buttonStyle(.web(.subtle))
            }
        }
    }

    // MARK: Viewport

    private var viewport: some View {
        let rows = filtered
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: 0).id("top")
                    if rows.isEmpty {
                        Text(records.isEmpty ? "No log records captured yet." : "No records match the current filter.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.mut)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 24)
                    } else {
                        ForEach(rows, id: \.self) { record in
                            LogRow(record: record)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(minHeight: 200, maxHeight: 520)
            .background(Theme.bg, in: RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous).strokeBorder(Theme.line))
            .onChange(of: rows.count) {
                guard autoScroll, live else { return }
                if motionOff {
                    proxy.scrollTo("top", anchor: .top)
                } else {
                    withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("top", anchor: .top) }
                }
            }
        }
    }

    // MARK: Tail

    /// Initial window, then — while LIVE and the app is active — `?since=` every 3 s.
    private func tail() async {
        await poll()
        guard live else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3))
            if Task.isCancelled { break }
            if scenePhase == .active { await poll() }
        }
    }

    private func poll() async {
        guard let client = model.client else { return }
        do {
            let rows = try await client.systemLogs(since: since, limit: Self.maxRecords)
            setFailed(false)
            guard let newest = rows.first?.ts else { return }
            since = max(since ?? 0, newest)
            records = Array((rows + records).prefix(Self.maxRecords))
        } catch is CancellationError {
        } catch {
            if (error as? URLError)?.code == .cancelled { return }
            setFailed(true)
        }
    }

    private func setFailed(_ value: Bool) {
        guard failed != value else { return }
        SettingsMotion.perform(motionOff, .easeOut(duration: 0.2)) { failed = value }
    }

    /// Drops the view and moves the high-water mark to now so older rows can't tail back in.
    private func clear() {
        since = Date.now.timeIntervalSince1970
        records = []
    }

    private func download() {
        guard let client = model.client else { return }
        downloading = true
        Task {
            defer { downloading = false }
            do {
                let data = try await client.downloadLogs()
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("fusionha.log")
                try data.write(to: url, options: .atomic)
                shareItem = FetchShareItem(url: url)
            } catch {
                toaster.show(error.settingsMessage, title: "Download failed", tone: .error)
            }
        }
    }

    static func rank(_ level: String) -> Int {
        levels.firstIndex(of: level.uppercased()) ?? 0
    }
}

// MARK: Row

private struct LogRow: View {
    let record: LogRecord
    @State private var open = false
    @Environment(\.settingsMotionOff) private var motionOff

    private var level: String { record.level.uppercased() }

    private var color: Color {
        switch level {
        case "DEBUG": Theme.dim
        case "INFO": Theme.grab
        case "WARNING": Theme.miss
        case "ERROR", "CRITICAL": Theme.danger
        default: Theme.mut
        }
    }

    private var label: String { level == "WARNING" ? "WARN" : level }

    var body: some View {
        let hasTrace = !(record.traceback ?? "").isEmpty
        VStack(alignment: .leading, spacing: 0) {
            if hasTrace {
                Button {
                    SettingsMotion.perform(motionOff, .easeOut(duration: 0.2)) { open.toggle() }
                } label: { line(hasTrace: true) }
                .buttonStyle(.plain)
                .accessibilityValue(open ? "Traceback shown" : "Traceback hidden")
            } else {
                line(hasTrace: false)
            }
            if hasTrace && open, let trace = record.traceback {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(trace)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(Theme.txt.opacity(0.85))
                        .textSelection(.enabled)
                        .fixedSize()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .background(Theme.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
                .padding(.leading, 40)
                .padding(.trailing, 14)
                .padding(.top, 2)
                .padding(.bottom, 8)
                .transition(.opacity)
            }
        }
        .background(
            LinearGradient(colors: [color.opacity(0.10), color.opacity(0)], startPoint: .leading, endPoint: .init(x: 0.45, y: 0.5))
        )
    }

    private func line(hasTrace: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle().fill(color).frame(width: 7, height: 7)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
            (Text(Self.stamp(record.ts)).foregroundStyle(Theme.dim)
             + Text("  ")
             + Text(label).fontWeight(.bold).foregroundStyle(color)
             + Text("  ")
             + Text(record.logger).foregroundStyle(Theme.mut)
             + Text("  ")
             + Text(record.message).foregroundStyle(Theme.txt))
                .font(.system(size: 12.5, design: .monospaced))
                .lineSpacing(2)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            if hasTrace {
                Text("▶")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.dim)
                    .rotationEffect(.degrees(open ? 90 : 0))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }

    /// Local `HH:mm:ss.SSS`.
    static func stamp(_ ts: Double) -> String {
        stampFormatter.string(from: Date(timeIntervalSince1970: ts))
    }

    private static let stampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
}

/// The LIVE pulse: a breathing dot while live (static under Reduce Motion).
private struct LiveDot: View {
    let live: Bool
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var dim = false

    var body: some View {
        Circle()
            .fill(live ? Theme.grab : Theme.dim)
            .frame(width: 8, height: 8)
            .background(Circle().fill(Theme.grab.opacity(live ? 0.22 : 0)).padding(-3))
            .opacity(live && dim && !motionOff ? 0.35 : 1)
            .animation(live && !motionOff ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: dim)
            .onAppear { dim = true }
            .accessibilityHidden(true)
    }
}
