import SwiftUI
import FusionhaKit

/// Settings → System (`SystemTasksPanel.tsx`): the live Commands strip, the
/// scheduled tasks with a ticking next-run countdown and Run now, and the
/// collapsible "Library metadata" group with Run all.
struct SystemTasksPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var tasks: [SystemTask] = []
    @State private var commands: [SystemCommand] = []
    @State private var loaded = false
    @State private var error: String?
    /// Just-triggered names, so Run now disables before the next poll lands.
    @State private var pending: Set<String> = []
    @State private var groupOpen = SystemTaskFormat.groupOpen
    @State private var toaster = FetchToaster()
    @State private var confirm: FetchConfirm?

    static let metadataGroup = ["metadata-refresh", "metadata-refresh-active", "air-times", "anime-ids"]

    private var runningNames: Set<String> {
        Set(commands.filter { $0.status == "running" }.map(\.name)).union(pending)
    }

    private func isRunning(_ task: SystemTask) -> Bool {
        task.running || runningNames.contains(task.name)
    }

    private var anyRunning: Bool {
        tasks.contains(where: isRunning) || commands.contains { $0.status == "running" }
    }

    var body: some View {
        FetchingPage(slug: "system", toaster: toaster, confirm: $confirm, refresh: load) {
            VStack(alignment: .leading, spacing: 12) {
                CommandsStrip(commands: commands)
                    .fetchReveal(0)
                if !loaded {
                    Text(error ?? "Loading scheduled tasks…")
                        .font(.system(size: 13)).foregroundStyle(Theme.mut)
                        .padding(.vertical, 8).padding(.horizontal, 2)
                } else if tasks.isEmpty {
                    Text("No scheduled tasks are registered.")
                        .font(.system(size: 13)).foregroundStyle(Theme.mut)
                        .padding(.vertical, 8).padding(.horizontal, 2)
                } else {
                    taskList.fetchReveal(1)
                }
            }
        }
        .task { await poll() }
    }

    // MARK: List

    private var taskList: some View {
        let grouped = Self.metadataGroup.compactMap { name in tasks.first { $0.name == name } }
        let flat = tasks.filter { !Self.metadataGroup.contains($0.name) }
        return TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 0) {
                ForEach(Array(flat.enumerated()), id: \.element.id) { index, task in
                    if index > 0 { Divider().overlay(Theme.line) }
                    TaskRow(task: task, running: isRunning(task), now: context.date) { run(task.name) }
                }
                if !grouped.isEmpty {
                    if !flat.isEmpty { Divider().overlay(Theme.line) }
                    group(grouped, now: context.date)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous).strokeBorder(Theme.line))
    }

    private func group(_ members: [SystemTask], now: Date) -> some View {
        let running = members.filter(isRunning).count
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    SettingsMotion.perform(motionOff, .timingCurve(0.65, 0, 0.35, 1, duration: 0.32)) {
                        groupOpen.toggle()
                    }
                    SystemTaskFormat.groupOpen = groupOpen
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.mut)
                            .rotationEffect(.degrees(groupOpen ? 90 : 0))
                        Image(systemName: "cylinder.split.1x2")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.cyan)
                            .frame(width: 26, height: 26)
                            .background(Theme.indigo.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Library metadata")
                                .font(.system(size: 13.5, weight: .bold)).foregroundStyle(Theme.txt)
                            Text("via TMDB · TVmaze · AniDB")
                                .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.dim)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isHeader)
                .accessibilityValue(groupOpen ? "Expanded" : "Collapsed")
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(members.count) task\(members.count == 1 ? "" : "s") · \(running) running")
                        .font(.system(size: 11.5).monospacedDigit()).foregroundStyle(Theme.mut)
                    Button("Run all") { members.forEach { run($0.name) } }
                        .buttonStyle(.web(.primary))
                        .disabled(running == members.count)
                }
            }
            .padding(.vertical, 14)

            if groupOpen {
                VStack(spacing: 0) {
                    ForEach(Array(members.enumerated()), id: \.element.id) { index, task in
                        if index > 0 { Divider().overlay(Theme.line) }
                        TaskRow(task: task, running: isRunning(task), now: now, child: true) { run(task.name) }
                    }
                }
                .padding(.leading, 16)
                .overlay(alignment: .leading) { Rectangle().fill(Theme.line).frame(width: 1) }
                .padding(.bottom, 6)
                .transition(motionOff ? .identity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipped()
    }

    // MARK: Data

    private func run(_ name: String) {
        guard let client = model.client else { return }
        pending.insert(name)
        Task {
            do {
                try await client.runSystemTask(name: name)
            } catch {
                toaster.error(error, title: "Couldn’t start \(SystemTaskFormat.label(name))")
            }
            await load()
            pending.remove(name)
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            async let t = client.systemTasks()
            async let c = client.systemCommands()
            let (newTasks, newCommands) = try await (t, c)
            tasks = newTasks
            commands = newCommands
            error = nil
        } catch is CancellationError {
            return
        } catch {
            self.error = error.settingsMessage
        }
        loaded = true
    }

    /// The web's cadence: 2 s while anything runs, else commands every 8 s and
    /// tasks every 30 s.
    private func poll() async {
        await load()
        var tick = 0
        while !Task.isCancelled {
            let fast = anyRunning
            try? await Task.sleep(for: .seconds(fast ? 2 : 8))
            if Task.isCancelled { break }
            tick += 1
            if fast || tick % 4 == 0 {
                await load()
            } else if let client = model.client, let fresh = try? await client.systemCommands() {
                commands = fresh
            }
        }
    }
}

// MARK: Row

private struct TaskRow: View {
    let task: SystemTask
    let running: Bool
    let now: Date
    var child = false
    let onRun: () -> Void

    var body: some View {
        let manual = task.intervalSeconds <= 0
        let countdown = manual ? nil : SystemTaskFormat.countdown(task.nextRun, now: now)
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(SystemTaskFormat.label(task.name))
                        .font(.system(size: child ? 12.75 : 13.5, weight: .semibold))
                        .foregroundStyle(Theme.txt)
                    if running {
                        RunningRing()
                    } else {
                        OutcomeGlyph(result: task.lastResult)
                    }
                }
                metaLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 6) {
                Text(running ? "Running…" : (manual ? "—" : countdown?.text ?? "—"))
                    .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                    .foregroundStyle(countdown?.due == true && !running ? Theme.miss : Theme.mut)
                    .contentTransition(.numericText(countsDown: true))
                Button(running ? "Running…" : "Run now", action: onRun)
                    .buttonStyle(.web(.subtle))
                    .disabled(running)
                    .accessibilityLabel("Run \(SystemTaskFormat.label(task.name)) now")
            }
            .frame(minWidth: 76, alignment: .trailing)
        }
        .padding(.vertical, child ? 11 : 14)
    }

    private var metaLine: some View {
        var parts = [SystemTaskFormat.schedule(task.intervalSeconds),
                     "Last run \(SystemTaskFormat.lastRun(task.lastRun, now: now))"]
        if let duration = task.lastDuration { parts.append("took \(SystemTaskFormat.duration(duration))") }
        return Text(parts.joined(separator: " · "))
            .font(.system(size: 12).monospacedDigit())
            .foregroundStyle(Theme.mut)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The in-flight ring; a static dot under Reduce Motion.
private struct RunningRing: View {
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var spin = false

    var body: some View {
        if motionOff {
            Circle().fill(Theme.grab).frame(width: 9, height: 9)
                .accessibilityLabel("Running")
        } else {
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(Theme.grab, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .background(Circle().stroke(Theme.grab.opacity(0.28), lineWidth: 2))
                .frame(width: 11, height: 11)
                .rotationEffect(.degrees(spin ? 360 : 0))
                .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: spin)
                .onAppear { spin = true }
                .accessibilityLabel("Running")
        }
    }
}

/// ✓ / ! for the last outcome, popping in with a spring.
private struct OutcomeGlyph: View {
    let result: String?
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var shown = false

    var body: some View {
        if result == "completed" || result == "failed" {
            let failed = result == "failed"
            Image(systemName: failed ? "exclamationmark" : "checkmark")
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(failed ? Theme.danger : Theme.done)
                .frame(width: 15, height: 15)
                .background((failed ? Theme.danger : Theme.done).opacity(0.16), in: Circle())
                .scaleEffect(shown || motionOff ? 1 : 0.6)
                .opacity(shown || motionOff ? 1 : 0)
                .onAppear {
                    withAnimation(motionOff ? nil : .spring(response: 0.25, dampingFraction: 0.6)) { shown = true }
                }
                .accessibilityLabel(failed ? "Last run failed" : "Last run completed")
        }
    }
}

/// The live Commands strip: in-flight runs with a sweeping shimmer.
private struct CommandsStrip: View {
    let commands: [SystemCommand]

    var body: some View {
        let running = commands.filter { $0.status == "running" }
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("Commands").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
                Spacer()
                Text(running.isEmpty ? "Idle" : "\(running.count) running")
                    .font(.system(size: 11.5, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.mut)
            }
            if running.isEmpty {
                Text("No commands are running right now.")
                    .font(.system(size: 12)).foregroundStyle(Theme.mut)
            } else {
                ForEach(running) { command in
                    HStack(spacing: 12) {
                        Text(SystemTaskFormat.label(command.name))
                            .font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.txt)
                            .lineLimit(1)
                        ShimmerTrack()
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous).strokeBorder(Theme.line))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Active commands")
    }
}

private struct ShimmerTrack: View {
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var phase = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.grab.opacity(0.16))
                if motionOff {
                    Capsule().fill(Theme.grab.opacity(0.55))
                } else {
                    Capsule().fill(Theme.fusion)
                        .frame(width: geo.size.width * 0.45)
                        .offset(x: geo.size.width * 0.45 * (phase ? 1.6 : -0.6))
                        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: false), value: phase)
                        .onAppear { phase = true }
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 6)
    }
}

// MARK: Format

/// `system-tasks-format.ts`: labels, schedule, durations, last-run and countdown.
enum SystemTaskFormat {
    private static let labels: [String: String] = [
        "rss_sync": "RSS Sync",
        "import_poll": "Import & Download Poll",
        "metadata_refresh": "Metadata Refresh",
        "metadata-refresh": "Full catalog sync",
        "metadata-refresh-active": "Active series sync",
        "air-times": "Air-times",
        "anime-ids": "Anime IDs",
    ]

    static func label(_ name: String) -> String {
        if let known = labels[name] { return known }
        return name.split(whereSeparator: { $0 == "_" || $0 == "-" })
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    static func schedule(_ seconds: Int) -> String {
        seconds <= 0 ? "Runs with each sync" : "Every \(interval(seconds))"
    }

    static func interval(_ seconds: Int) -> String {
        if seconds <= 0 { return "—" }
        if seconds % 3600 == 0 {
            let h = seconds / 3600
            return "\(h) hour\(h == 1 ? "" : "s")"
        }
        if seconds % 60 == 0 { return "\(seconds / 60) min" }
        return "\(seconds) sec"
    }

    static func duration(_ seconds: Double) -> String {
        if seconds.isNaN { return "—" }
        if seconds < 1 { return "\(Int((seconds * 1000).rounded()))ms" }
        if seconds < 60 { return String(format: "%.1fs", seconds) }
        let m = Int(seconds / 60)
        let s = Int(seconds.truncatingRemainder(dividingBy: 60).rounded())
        return "\(m)m \(String(format: "%02d", s))s"
    }

    static func lastRun(_ iso: String?, now: Date) -> String {
        guard let iso else { return "Never" }
        guard let then = FetchFormat.date(iso) else { return "—" }
        let secs = max(0, Int(now.timeIntervalSince(then).rounded()))
        if secs < 45 { return "just now" }
        if secs < 3600 { return "\(Int((Double(secs) / 60).rounded())) min ago" }
        if secs < 86_400 { return "\(Int((Double(secs) / 3600).rounded())) hr ago" }
        let d = Int((Double(secs) / 86_400).rounded())
        return "\(d) day\(d == 1 ? "" : "s") ago"
    }

    static func countdown(_ iso: String?, now: Date) -> (text: String, due: Bool) {
        guard let target = FetchFormat.date(iso) else { return ("—", false) }
        let remaining = Int(target.timeIntervalSince(now).rounded())
        if remaining <= 0 { return ("due now", true) }
        if remaining < 3600 {
            return ("in \(remaining / 60):\(String(format: "%02d", remaining % 60))", false)
        }
        return ("in \(remaining / 3600)h \(String(format: "%02d", (remaining % 3600) / 60))m", false)
    }

    /// The group remembers its open state (default open), like the web's localStorage key.
    static var groupOpen: Bool {
        get { UserDefaults.standard.string(forKey: "fusionha.system-tasks.group.library-metadata.open") != "closed" }
        set { UserDefaults.standard.set(newValue ? "open" : "closed", forKey: "fusionha.system-tasks.group.library-metadata.open") }
    }
}
