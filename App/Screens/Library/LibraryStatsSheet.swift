import SwiftUI
import FusionhaKit


/// "Library stats" (LibraryPulse.tsx mobile sheet): the connection line, stat
/// buttons that set the status filter, the health / 4K coverage / on-disk
/// meters, then In progress and Needs attention, and a link to Activity.
struct LibraryStatsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.motionEnabled) private var motion
    let pulse: PulseStats
    @Binding var status: LibraryStatus
    /// Close the sheet, then open Settings › Indexers.
    var manageIndexers: () -> Void = {}
    @State private var grown = false
    @State private var feed = StatsSheetFeed.shared
    /// `/health`, read when the sheet opens (the web shares the shell's query).
    @State private var connection: ConnectionLine = .connecting

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Library stats").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.txt)
                    .padding(.trailing, 36)
                connectionLine
                LibraryWrap(spacing: 8) {
                    ForEach(LibraryPulseParts.order, id: \.0) { entry in
                        PulseStatButton(key: entry.0, label: entry.1, pulse: pulse, status: $status) { dismiss() }
                    }
                }
                PulseMeters(pulse: pulse, grown: grown)
                .padding(.top, 16)
                .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
                section("In progress") {
                    StatsInProgressList(operations: feed.inProgress) { _ in
                        dismiss()
                        model.tab = .activity
                    }
                }
                section("Needs attention", id: "needs-attention") {
                    StatsAttentionList(indexers: feed.indexers, rows: feed.rows, manageIndexers: {
                        manageIndexers()
                        dismiss()
                    }, openRow: { row in
                        dismiss()
                        model.statsOpenRow(row)
                    }, act: { row in
                        dismiss()
                        model.statsAct(row)
                    }, dismissRow: { model.statsDismiss($0, feed: feed) })
                    .padding(.horizontal, -16)
                }
                Button {
                    dismiss()
                    model.pendingActivityTab = .tasks
                    model.tab = .activity
                } label: {
                    Text("View all activity ›")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.grab)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        #if DEBUG
        .task(id: feed.loaded) {
            guard feed.loaded, ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_STATS"] == "attention" else { return }
            try? await Task.sleep(for: .milliseconds(600))
            proxy.scrollTo("needs-attention", anchor: .top)
        }
        #endif
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.mut)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .padding(.top, 14)
            .padding(.trailing, 14)
            .accessibilityLabel("Close")
        }
        .onAppear {
            withAnimation(motion ? Motion.reveal(1.1) : nil) { grown = true }
        }
        .task { await checkHealth() }
        .task {
            while !Task.isCancelled {
                if let client = model.client { await feed.load(client: client, queue: model.queue) }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    /// `sheetConn`: a dot (green when connected, red when offline, dim while
    /// connecting or unknown) and the four-state label.
    private var connectionLine: some View {
        let dot: Color = connection == .ok ? Theme.done : connection == .offline ? Theme.danger : Theme.dim
        return HStack(spacing: 8) {
            Circle().fill(dot).frame(width: 8, height: 8)
                .shadow(color: connection == .ok || connection == .offline ? dot.opacity(0.8) : .clear, radius: 3)
            Text(connection.label)
                .font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.mut)
        }
        .accessibilityElement(children: .combine)
    }

    private func checkHealth() async {
        guard let client = model.client else { connection = .unknown; return }
        do {
            let health = try await client.health()
            connection = ConnectionLine(loading: false, failed: false, status: health.status)
        } catch is CancellationError {
            return
        } catch {
            connection = .offline
        }
    }

    /// `.sheetSection`: a hairline, then the 11/700 uppercase label.
    private func section<Content: View>(_ title: String, id: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.22)
                .foregroundStyle(Theme.dim)
            content()
        }
        .padding(.top, 16)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        .id(id ?? title)
    }
}
