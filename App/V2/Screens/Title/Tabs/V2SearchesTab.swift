import SwiftUI
import FusionhaKit

/// v2's Searches tab (mock browse-title.js `searchesTab`): one line on what
/// it is, then a W1 card per run that touched this title, newest first
/// (`V2SearchRunCard`: what ran, when, what it checked, grabbed and skipped,
/// and its decision trail on a tap). The feed, the version scope and the
/// polling are v1's (`SearchesFeed`: 2 s while a run is live, else 15 s); a
/// live search draws `V2LiveSearchRunCard` (progress and Stop, frosted).
struct V2SearchesTab: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.pagePalette) private var page
    @Environment(\.detailReduceMotion) private var reduce
    let detail: ItemDetail
    @State private var feed = SearchesFeed()
    @State private var toaster = ActToaster()
    @State private var limit = 12

    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        let version = store.focusedVersion
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Every search that touched this title, with what it grabbed and why.")
                    .font(.system(size: 13))
                    .foregroundStyle(muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if detail.editions.count > 1 { DetailVersionMenu(detail: detail) }
            }
            .v2FadesUnderTitleBar()
            if !feed.loaded {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 30)
            } else if feed.runs.isEmpty {
                Text("No searches yet. Manual searches, RSS syncs and scheduled sweeps that touch this title show up here.")
                    .font(.system(size: 14))
                    .foregroundStyle(muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .v2CardStyle(padding: 14, radius: 18)
            } else {
                runs
            }
        }
        .environment(toaster)
        .environment(\.actReduceMotion, reduce)
        .overlay { ActToastOverlay(toaster: toaster) }
        .task(id: version?.id) {
            feed.versionId = version?.id
            feed.tier = version?.tier
            await feed.load(store.client, itemId: store.itemId)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(feed.anyRunning ? 2 : 15))
                if Task.isCancelled { break }
                await feed.load(store.client, itemId: store.itemId)
            }
        }
    }

    @ViewBuilder
    private var runs: some View {
        let live = feed.runs.filter { $0.status == "running" && $0.search != nil }
        let done = feed.runs.filter { !($0.status == "running" && $0.search != nil) }
        // Run-wide counters are only this title's on its own searches: a
        // library sweep's grabs may be other titles'.
        let firstWithGrab = done.first(where: { $0.itemId == detail.id && $0.grabbed + $0.upgraded > 0 })?.id
        ForEach(live) { run in
            V2LiveSearchRunCard(run: run) { Task { await feed.load(store.client, itemId: store.itemId) } }
        }
        ForEach(done.prefix(limit)) { run in
            V2SearchRunCard(run: run, detail: detail, startsOpen: run.id == firstWithGrab)
        }
        if done.count > limit {
            Button("Show \(min(12, done.count - limit)) more") { limit += 12 }
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(page?.ink ?? Theme.txt)
                .buttonStyle(.glass)
                .v2FadesUnderTitleBar()
        }
    }
}
