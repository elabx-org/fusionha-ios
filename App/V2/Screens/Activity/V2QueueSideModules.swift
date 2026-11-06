import SwiftUI
import FusionhaKit

/// Up next (mock `upnext`): the queued downloads still waiting for a slot,
/// then the next RSS sync, missing search and upgrade search. Hidden when
/// there is neither.
struct V2QueueUpNextModule<Row: View>: View {
    let queued: [QueueItem]
    let tasks: IdleSummary.Tasks?
    /// "Queued" on the open Duo, where the overview column has Up next.
    var caption = "Up next"
    @ViewBuilder let row: (QueueItem) -> Row
    @State private var showsAll = false

    var body: some View {
        let runs = V2ScheduledRun.all(tasks)
        if !queued.isEmpty || !runs.isEmpty {
            WidgetModule(caption: queued.isEmpty || tasks != nil ? caption : "\(caption) · \(queued.count)",
                         systemImage: "clock") {
                if queued.count > 4 {
                    Button(showsAll ? "Fewer" : "All \(queued.count)") { showsAll.toggle() }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.accentText)
                        .buttonStyle(.plain)
                }
            } content: {
                ForEach(showsAll ? queued : Array(queued.prefix(4))) { row($0) }
                ForEach(runs) { V2ScheduledRunRow(run: $0) }
            }
        }
    }
}

/// A scheduled task's next run, from the idle summary.
struct V2ScheduledRun: Identifiable {
    let id: String
    let title: String
    let every: String
    let icon: String
    let next: Date?
    let running: Bool

    static func all(_ tasks: IdleSummary.Tasks?) -> [V2ScheduledRun] {
        guard let tasks else { return [] }
        let list: [(String, String, String, IdleSummary.Task?)] = [
            ("rss", "RSS sync", "arrow.clockwise", tasks.rss),
            ("search", "Missing search", "magnifyingglass", tasks.search),
            ("upgrade", "Upgrade search", "arrow.up", tasks.upgrade),
        ]
        return list.compactMap { key, title, icon, task in
            guard let task else { return nil }
            return V2ScheduledRun(id: key, title: title, every: IdleSummary.everyLabel(seconds: task.intervalSeconds),
                                  icon: icon, next: task.nextRunDate, running: task.running)
        }
        .sorted { ($0.next ?? .distantFuture) < ($1.next ?? .distantFuture) }
    }
}

struct V2ScheduledRunRow: View {
    let run: V2ScheduledRun
    @Environment(\.pagePalette) private var page

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: run.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(page?.ink ?? Theme.txt)
                .frame(width: 30, height: 30)
                .background((page?.ink ?? Theme.txt).opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(run.title).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(page?.ink ?? Theme.txt)
                Text(run.every).font(.system(size: 12.5)).foregroundStyle(page?.inkMuted ?? Theme.mut)
            }
            Spacer(minLength: 8)
            Text(run.running ? "Running" : (run.next?.formatted(date: .omitted, time: .shortened) ?? "–"))
                .font(.system(size: 14, weight: .bold).monospacedDigit())
                .foregroundStyle(run.running ? Theme.accentText : (page?.ink ?? Theme.txt))
        }
        .accessibilityElement(children: .combine)
    }
}

/// Just finished (v1's 20-second shelf before History): what imported or
/// failed a moment ago, each with its version's badge.
struct V2JustFinishedModule: View {
    let rows: (rows: [QueueLogic.Finished], overflow: Int)
    let openHistory: () -> Void
    @Environment(\.pagePalette) private var page

    var body: some View {
        if !rows.rows.isEmpty {
            WidgetModule(caption: "Just finished", systemImage: "checkmark") {
                Button("History", action: openHistory)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accentText)
                    .buttonStyle(.plain)
            } content: {
                ForEach(rows.rows) { entry in
                    HStack(spacing: 11) {
                        PosterImage(url: TMDBImage.resized(entry.item.posterUrl, to: "w185"), size: CGSize(width: 30, height: 45))
                            .frame(width: 30, height: 45)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.item.title).font(.system(size: 14.5, weight: .semibold))
                                .foregroundStyle(page?.ink ?? Theme.txt).lineLimit(1)
                            Text(line(entry)).font(.system(size: 12.5)).foregroundStyle(page?.inkMuted ?? Theme.mut).lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        EditionBadge(tier: entry.item.tier, state: entry.failed ? .missing : .onDisk, showsCount: false)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func line(_ entry: QueueLogic.Finished) -> String {
        let what = entry.count > 1 ? "\(entry.count) files" : (QueueCardText.subtitle(entry.item) ?? "Movie")
        return "\(what) · \(entry.failed ? "failed" : "imported")"
    }
}
