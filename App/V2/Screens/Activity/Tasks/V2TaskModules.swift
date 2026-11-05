import SwiftUI
import FusionhaKit

/// A task's icon tile: one ink on a soft tile, the danger ink for a failure.
struct V2TaskTile: View {
    let systemImage: String
    var failed = false
    var size: CGFloat = 30
    @Environment(\.pagePalette) private var page

    var body: some View {
        let ink = failed ? Theme.dangerText : (page?.ink ?? Theme.txt)
        Image(systemName: systemImage)
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(ink)
            .frame(width: size, height: size)
            .background(ink.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// RSS sync (mock `rss`): how often, the last run and the next, Run now,
/// and the latest run's releases, evaluated and grabbed.
struct V2RssModule: View {
    let task: ActivitySystemTask
    let latest: ActivityRun?
    var selected = false
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.pagePalette) private var page
    @State private var starting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                V2TaskTile(systemImage: "dot.radiowaves.up.forward")
                Text("RSS sync").font(.system(size: 15.5, weight: .bold)).foregroundStyle(page?.ink ?? Theme.txt)
                Spacer(minLength: 8)
                V2CapsuleButton(title: task.running ? "Running" : "Run now", systemImage: "play.fill",
                                busy: starting || task.running) { run() }
            }
            Text(V2TaskCopy.schedule(task, running: "Checking the indexer feeds…"))
                .font(.system(size: 13)).foregroundStyle(page?.inkMuted ?? Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
            if let latest {
                HStack(spacing: 16) {
                    V2KeyFigure(value: latest.releases.formatted(), label: "releases")
                    V2KeyFigure(value: latest.evaluated.formatted(), label: "evaluated")
                    V2KeyFigure(value: (latest.grabbed + latest.upgraded).formatted(), label: "grabbed")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background { ModuleSurface(selected: selected) }
    }

    private func run() {
        starting = true
        Task {
            defer { starting = false }
            do {
                try await model.client?.runTask(name: task.name)
                toaster.show("RSS sync started")
            } catch {
                toaster.error(error)
            }
        }
    }
}

/// Scheduled (mock `sched`): every scheduled job, its rhythm, its last run
/// (a failure in the danger ink) and when it runs next.
struct V2ScheduledModule: View {
    let tasks: [ActivitySystemTask]
    @Environment(\.pagePalette) private var page

    var body: some View {
        WidgetModule(caption: "Scheduled", systemImage: "clock") {
            ForEach(tasks, id: \.name) { task in
                let failed = V2TaskCopy.failed(task)
                HStack(spacing: 11) {
                    V2TaskTile(systemImage: V2TaskCopy.icon(task.name), failed: failed, size: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(ActFmt.taskLabel(task.name)).font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(page?.ink ?? Theme.txt).lineLimit(1)
                        Text(V2TaskCopy.schedule(task, running: "running now"))
                            .font(.system(size: 12))
                            .foregroundStyle(failed ? Theme.dangerText : (page?.inkMuted ?? Theme.mut))
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(task.running ? "now" : (V2QueueTime.clock(task.nextRun) ?? ActFmt.countdown(task.nextRun)))
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                        .foregroundStyle(task.running ? Theme.accentText : (page?.ink ?? Theme.txt))
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Media enrichment (mock `enrich`): files read of the library, what is
/// pending and what needs a look, with a progress rail while it runs;
/// v1's issue groups and per-import controls follow it.
struct V2EnrichmentModule: View {
    let status: ActivityEnrichmentStatus
    @Environment(\.pagePalette) private var page

    var body: some View {
        let total = max(0, status.totalFiles ?? 0)
        let read = min(max(0, status.enrichedFiles ?? 0), total)
        let pending = max(0, status.pendingFiles ?? 0)
        let issues = max(0, status.issueFiles ?? 0)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                V2TaskTile(systemImage: "doc.text.magnifyingglass")
                Text("Media enrichment").font(.system(size: 15.5, weight: .bold)).foregroundStyle(page?.ink ?? Theme.txt)
            }
            Text("\(read.formatted()) of \(total.formatted()) files read · \(pending == 0 ? "nothing pending" : "\(pending.formatted()) pending")\(issues > 0 ? " · \(issues.formatted()) need a look" : "")")
                .font(.system(size: 13)).foregroundStyle(page?.inkMuted ?? Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
            if pending > 0, total > 0 {
                RailBarV2(progress: Double(read) / Double(total))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2CardStyle(padding: 14)
    }
}

/// The task cards' words.
enum V2TaskCopy {
    /// "Every 15 min · last 17:34, took 46s · next 17:49".
    static func schedule(_ task: ActivitySystemTask, running: String) -> String {
        if task.running { return running }
        var parts = [every(task.intervalSeconds)]
        if let last = task.lastRun {
            let took = task.lastDuration.map { ", took \(TasksLogic.duration($0))" } ?? ""
            parts.append("last \(V2QueueTime.clock(last) ?? ActFmt.relative(last))\(took)")
        }
        if let result = task.lastResult, !result.isEmpty, failed(task) { parts.append(result) }
        return parts.joined(separator: " · ")
    }

    static func every(_ seconds: Int) -> String {
        switch seconds {
        case ..<1: return "On demand"
        case ..<3600: return "Every \(max(1, seconds / 60)) min"
        case 86_400: return "Daily"
        case ..<86_400: return seconds % 3600 == 0 ? "Every \(seconds / 3600) h" : "Every \(seconds / 60) min"
        default: return seconds % 86_400 == 0 ? "Every \(seconds / 86_400) days" : "Every \(seconds / 3600) h"
        }
    }

    /// The last result reads as a failure.
    static func failed(_ task: ActivitySystemTask) -> Bool {
        guard let result = task.lastResult?.lowercased() else { return false }
        return result.contains("fail") || result.contains("error")
    }

    static func icon(_ name: String) -> String {
        let n = name.lowercased()
        if n.contains("upgrade") { return "arrow.up" }
        if n.contains("cutoff") { return "arrow.up.arrow.down" }
        if n.contains("missing") || n.contains("search") { return "magnifyingglass" }
        if n.contains("backup") { return "folder" }
        if n.contains("trash") || n.contains("sync") { return "arrow.triangle.2.circlepath" }
        if n.contains("refresh") || n.contains("metadata") { return "arrow.clockwise" }
        return "clock"
    }
}
