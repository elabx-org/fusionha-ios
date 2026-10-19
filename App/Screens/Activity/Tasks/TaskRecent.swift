import SwiftUI
import FusionhaKit

// MARK: - Recent

struct RecentGroupView: View {
    let group: TasksLogic.RunGroup
    let tasks: [ActivitySystemTask]
    var playful = false
    /// The `?focus=` run; reveals a collapsed older run.
    var focusRunId: Int?
    @State private var expanded: Bool
    @Environment(\.actReduceMotion) private var reduce

    init(group: TasksLogic.RunGroup, tasks: [ActivitySystemTask], playful: Bool = false, focusRunId: Int? = nil) {
        self.group = group
        self.tasks = tasks
        self.playful = playful
        self.focusRunId = focusRunId
        _expanded = State(initialValue: focusRunId.map { id in group.older.contains { $0.id == id } } ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            RecentRow(run: group.latest, tasks: tasks, playful: playful, focused: focusRunId == group.latest.id)
            if !group.older.isEmpty {
                Button {
                    if reduce { expanded.toggle() } else { withAnimation(.easeOut(duration: 0.18)) { expanded.toggle() } }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                        Text(TasksLogic.earlierLabel(group))
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.dim)
                    .padding(.leading, 16)
                    .padding(.trailing, 14)
                    .padding(.vertical, 8)
                    .background(Theme.bg, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(expanded ? .isSelected : [])
                if expanded {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(group.older) { run in
                            RecentRow(run: run, tasks: tasks, playful: playful, focused: focusRunId == run.id)
                        }
                    }
                    .padding(.leading, 16)
                    .transition(reduce ? .identity : .opacity.combined(with: .offset(y: -4)))
                }
            }
        }
    }
}

struct RecentRow: View {
    let run: ActivityRun
    let tasks: [ActivitySystemTask]
    var playful = false
    /// The `?focus=` target: its trail opens and the row flashes.
    var focused = false
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.actReduceMotion) private var reduce
    @State private var open: Bool

    init(run: ActivityRun, tasks: [ActivitySystemTask], playful: Bool = false, focused: Bool = false) {
        self.run = run
        self.tasks = tasks
        self.playful = playful
        self.focused = focused
        _open = State(initialValue: focused)
    }

    var body: some View {
        let expandable = run.releases > 0 || run.evaluated > 0 || run.skippedInFlight == true
        let stuck = TasksLogic.isStuckNoGrab(run)
        let kind = TasksLogic.iconKind(run)
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    toggle()
                } label: {
                    HStack(alignment: .center, spacing: 13) {
                        TaskIconTile(color: stuck ? Theme.miss : taskIconColor(kind)) { Image(systemName: taskIcon(kind)) }
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.card).padding(-4))
                        VStack(alignment: .leading, spacing: 0) {
                            TaskNameLine(run: run)
                            TaskFactLine(run: run, playful: playful)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!expandable)
                HStack(spacing: 12) {
                    Spacer(minLength: 0)
                    Text(ActFmt.relative(run.endedAt ?? run.startedAt))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                    if expandable {
                        Button(action: toggle) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.dim)
                                .rotationEffect(.degrees(open ? 90 : 0))
                                .frame(width: 30, height: 30)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(open ? "Hide decision trail" : "Show decision trail")
                    }
                    actions
                }
                .frame(minHeight: 30)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            if expandable && open {
                RunTrail(runId: run.id)
                    .transition(reduce ? .identity : .opacity)
            }
        }
        .modifier(TaskCard(wash: stuck ? Theme.miss : nil))
        .taskFocusFlash(focused)
        .id(TaskFocus.scrollId(run.id))
    }

    private func toggle() {
        if reduce { open.toggle() } else { withAnimation(.easeOut(duration: 0.2)) { open.toggle() } }
    }

    /// `RunActions`: Open (item runs), Search again, Run {Task} again.
    @ViewBuilder
    private var actions: some View {
        let sched = TasksLogic.schedulerTask(for: run, in: tasks)
        let title = run.targetTitle ?? run.name
        if run.itemId != nil || sched != nil {
            HStack(spacing: 0) {
                if let itemId = run.itemId {
                    ActIconButton(systemImage: "arrow.up.right.square", label: "Open \(title) in library", tint: Theme.mut) { model.open(itemId) }
                }
                ActMoreMenu {
                    if let itemId = run.itemId {
                        Button("Search again", systemImage: "magnifyingglass") {
                            Task { await ActActions.search(model.client, toaster, itemId: itemId, message: "Searching again for \(title)") }
                        }
                    }
                    if let sched {
                        let label = ActFmt.taskLabel(sched.name)
                        Button("Run \(label) again", systemImage: "arrow.clockwise") {
                            Task {
                                do {
                                    try await model.client?.runTask(name: sched.name)
                                    toaster.show("\(label) started")
                                } catch { toaster.error(error) }
                            }
                        }
                    }
                }
            }
        }
    }
}
