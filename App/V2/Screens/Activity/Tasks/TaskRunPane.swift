import SwiftUI
import FusionhaKit

/// One task run on the open Duo's right page (or the phone's sheet), mock
/// activity-log.js `taskSplit`: what ran and when, the key figures, the
/// decision trail (v1's `RunTrail`) and the run's actions (v1 `RunActions`:
/// Open title, Search again, Run the task again).
struct TaskRunPane: View {
    let run: ActivityRun
    let tasks: [ActivitySystemTask]
    var playful = false
    /// The open Duo: a close button that brings the system modules back.
    var close: (() -> Void)?
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.pagePalette) private var page
    @State private var starting = false

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            figures
            trail
            actions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        let kind = TasksLogic.iconKind(run)
        return HStack(alignment: .top, spacing: 12) {
            V2TaskTile(systemImage: taskIcon(kind), failed: kind == .fail, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(run.name).font(.system(size: 22, weight: .bold)).foregroundStyle(ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(V2TaskRunCopy.when(run)).font(.system(size: 13)).foregroundStyle(muted)
                if let target = TasksLogic.targetDetail(run) {
                    Text(target).font(.system(size: 13, weight: .semibold)).foregroundStyle(ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                V2TaskFactLine(run: run, playful: playful)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let close {
                V2RoundIconButton(systemImage: "xmark", label: "Close run", size: 32, action: close)
            }
        }
    }

    private var figures: some View {
        HStack(spacing: 20) {
            V2KeyFigure(value: run.releases.formatted(), label: "releases")
            V2KeyFigure(value: run.evaluated.formatted(), label: "evaluated")
            V2KeyFigure(value: (run.grabbed + run.upgraded).formatted(),
                        label: run.upgraded > 0 ? "grabbed · \(run.upgraded) upgraded" : "grabbed")
            if run.errors > 0 {
                V2KeyFigure(value: run.errors.formatted(), label: run.errors == 1 ? "error" : "errors", tint: Theme.dangerText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2CardStyle(padding: 14)
    }

    @ViewBuilder
    private var trail: some View {
        VStack(alignment: .leading, spacing: 8) {
            V2ScopeSectionHead(title: "Decision trail", systemImage: "list.bullet.rectangle")
            if run.releases > 0 || run.evaluated > 0 || run.skippedInFlight == true {
                RunTrail(runId: run.id)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .v2CardStyle(padding: 0)
            } else {
                Text("Nothing was evaluated in this run, so there is no trail to show.")
                    .font(.system(size: 13)).foregroundStyle(muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .v2CardStyle(padding: 14)
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        let sched = TasksLogic.schedulerTask(for: run, in: tasks)
        let title = run.targetTitle ?? run.name
        if run.itemId != nil || sched != nil {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { actionButtons(sched: sched, title: title) }
                VStack(alignment: .leading, spacing: 8) { actionButtons(sched: sched, title: title) }
            }
        }
    }

    @ViewBuilder
    private func actionButtons(sched: ActivitySystemTask?, title: String) -> some View {
        if let itemId = run.itemId {
            V2CapsuleButton(title: "Open title", systemImage: "arrow.up.right.square") { model.open(itemId) }
            V2CapsuleButton(title: "Search again", systemImage: "magnifyingglass") {
                Task { await ActActions.search(model.client, toaster, itemId: itemId, message: "Searching again for \(title)") }
            }
        }
        if let sched {
            let label = ActFmt.taskLabel(sched.name)
            V2CapsuleButton(title: "Run \(label) again", systemImage: "arrow.clockwise", busy: starting || sched.running) {
                starting = true
                Task {
                    defer { starting = false }
                    do {
                        try await model.client?.runTask(name: sched.name)
                        toaster.show("\(label) started")
                    } catch { toaster.error(error) }
                }
            }
        }
    }
}

/// The run pane's and recent rows' words.
enum V2TaskRunCopy {
    /// "Today 17:34 to 17:35 · took 46s".
    static func when(_ run: ActivityRun) -> String {
        let start = V2QueueTime.clock(run.startedAt)
        let end = V2QueueTime.clock(run.endedAt)
        var parts: [String] = [ActFmt.relative(run.endedAt ?? run.startedAt)]
        if let start { parts.append(end.map { $0 == start ? start : "\(start) to \($0)" } ?? "since \(start)") }
        if let ms = run.durationMs, ms > 0 { parts.append("took \(TasksLogic.duration(Double(ms) / 1000))") }
        return parts.joined(separator: " · ")
    }

    /// "RSS Sync · 17:34".
    static func nameLine(_ run: ActivityRun) -> String {
        guard let clock = V2QueueTime.clock(run.endedAt ?? run.startedAt) else { return run.name }
        return "\(run.name) · \(clock)"
    }
}
