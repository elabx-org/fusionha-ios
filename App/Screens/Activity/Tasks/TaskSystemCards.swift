import SwiftUI
import FusionhaKit

// MARK: - System cards

struct EnrichmentCard: View {
    let status: ActivityEnrichmentStatus
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        let total = max(0, status.totalFiles ?? 0)
        let enriched = min(max(0, status.enrichedFiles ?? 0), total)
        let issues = max(0, status.issueFiles ?? 0)
        let pending = max(0, status.pendingFiles ?? 0)
        let pct = total > 0 ? min(100, Int((Double(enriched) / Double(total) * 100).rounded())) : 0
        let settled = pending == 0
        HStack(alignment: .center, spacing: 13) {
            if settled {
                TaskIconTile(color: Theme.done) { Image(systemName: "checkmark").fontWeight(.heavy) }
            } else {
                TaskIconTile(color: Theme.grab, spinning: !reduce) { TaskSpinnerGlyph() }
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("Media enrichment").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                Group {
                    if settled {
                        (Text("Complete").foregroundColor(Theme.done).fontWeight(.semibold)
                         + Text(" · \(enriched.formatted()) of \(total.formatted()) analysed")
                         + Text(issues > 0 ? " · " : "")
                         + Text(issues > 0 ? "\(issues.formatted()) need attention" : "").foregroundColor(Theme.miss))
                    } else {
                        Text("Analysing \(ActFmt.plural(pending, "file")) · \(pct)% · \(enriched.formatted()) of \(total.formatted()) done"
                             + (issues > 0 ? " · \(issues.formatted()) need attention" : ""))
                    }
                }
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.mut)
                .padding(.top, 3)
                .fixedSize(horizontal: false, vertical: true)
                TaskBar(fraction: settled ? 1 : Double(pct) / 100, live: !settled, done: settled)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(TaskCard(wash: settled ? nil : Theme.grab))
    }
}

struct RssSyncCard: View {
    let task: ActivitySystemTask
    let latestRun: ActivityRun?

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            TaskIconTile(color: task.running ? Theme.grab : Theme.edition, spinning: task.running) {
                Image(systemName: taskIcon(.rss))
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("RSS Sync").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                Group {
                    if task.running {
                        HStack(spacing: 5) {
                            ActPulseDot(color: Theme.grab, size: 7, spread: 6)
                            Text("checking indexer feeds…")
                        }
                    } else if let latestRun {
                        Text(TasksLogic.factualLine(latestRun))
                    } else {
                        Text(task.lastResult.map { "Last: \($0)" } ?? "Idle")
                    }
                }
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.mut)
                .padding(.top, 3)
                if !task.running {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let last = latestRun.map { " · last \(ActFmt.relative($0.endedAt ?? $0.startedAt, now: context.date))" } ?? ""
                        Text("next sync \(ActFmt.countdown(task.nextRun, now: context.date))\(last)")
                            .font(.system(size: 11.5).monospacedDigit())
                            .foregroundStyle(Theme.dim)
                            .padding(.top, 2)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .modifier(TaskCard())
    }
}

struct ScheduledCard: View {
    let tasks: [ActivitySystemTask]

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            TaskIconTile(color: Theme.unaired) { Image(systemName: taskIcon(.refresh)) }
            VStack(alignment: .leading, spacing: 0) {
                Text("Scheduled").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(tasks.map { "\(ActFmt.taskLabel($0.name)) \($0.running ? "running" : ActFmt.countdown($0.nextRun, now: context.date))" }
                        .joined(separator: " · "))
                        .font(.system(size: 12.5).monospacedDigit())
                        .foregroundStyle(Theme.mut)
                        .padding(.top, 3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .modifier(TaskCard())
    }
}
