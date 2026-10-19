import SwiftUI
import FusionhaKit

/// Activity › Tasks › System: "Watchlists & lists" (fusionha 0.4.215, web
/// `routes/tasks/watchlists/WatchlistsCard.tsx`; admin only, the tab gates
/// it). The overall line with its bar, one row per source, today's totals and
/// the three background jobs as small mono labels with status dots. State is
/// an ambient wash, never a border.
struct WatchlistsTaskCard: View {
    let summary: RequestSourcesSummary
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        let tone = WatchlistsTaskLogic.tone(summary)
        VStack(alignment: .leading, spacing: 0) {
            head(tone)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(summary.sources) { WatchlistsTaskSourceRow(source: $0) }
                if !WatchlistsTaskLogic.hasPlexSource(summary.sources) {
                    Text("Plex watchlist: nobody connected")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.mut)
                        .padding(.horizontal, 2)
                }
            }
            .padding(.top, 12)
            Text("TODAY")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.66)
                .foregroundStyle(Theme.dim)
                .padding(.top, 14)
                .padding(.bottom, 6)
            SyncCountGrid(cells: WatchlistsTaskLogic.todayCells(summary.today), label: "Today")
            jobs.padding(.top, 12)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(TaskCard(wash: tone.color))
    }

    private func head(_ tone: SyncVariant) -> some View {
        let running = summary.runningSources > 0
        return HStack(alignment: .center, spacing: 13) {
            TaskIconTile(color: tone.color, spinning: running && !reduce) {
                Image(systemName: "list.bullet")
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("Watchlists & lists").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                HStack(spacing: 6) {
                    if running { SyncDot(color: Theme.grab, live: true) }
                    WatchlistsTaskLogic.overall(summary).text
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.mut)
                .padding(.top, 3)
                .accessibilityElement(children: .combine)
                if running {
                    SyncBar(sync: SourceSync(state: "running", checked: summary.checked, total: summary.total),
                            label: "Watchlists and lists progress")
                        .padding(.top, 8)
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// request-source-sync · plex-watchlist-poll · letterboxd-csv-match, each with its dot.
    private var jobs: some View {
        let byName = Dictionary(summary.jobs.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        return ActFlow(spacing: 12, lineSpacing: 6) {
            ForEach(WatchlistsTaskLogic.jobs, id: \.self) { name in
                let job = byName[name]
                HStack(spacing: 5) {
                    Circle().fill(WatchlistsTaskLogic.jobTone(job).color).frame(width: 6, height: 6)
                    Text(name).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.mut)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(name), \(WatchlistsTaskLogic.jobHelp(job))")
                .help(WatchlistsTaskLogic.jobHelp(job))
            }
        }
    }
}

/// Recent's stand-in for the three job rows that moved into the card.
struct WatchlistsFoldedNote: View {
    var body: some View {
        Text(WatchlistsTaskLogic.foldedNote)
            .font(.system(size: 12))
            .foregroundStyle(Theme.mut)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 2)
            .padding(.bottom, 10)
    }
}
