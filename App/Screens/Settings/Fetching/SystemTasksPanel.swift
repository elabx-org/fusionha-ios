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
                            .foregroundStyle(Theme.i2)
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
