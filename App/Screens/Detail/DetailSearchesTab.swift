import SwiftUI
import FusionhaKit

// MARK: - Searches

/// The detail Searches tab (SearchesTab.tsx, ruling L9): the Tasks feed scoped
/// to this title (`touched_item`) and, with one version focused, to the runs
/// whose candidates belong to it. Live searches use the Tasks run cards,
/// finished ones the Recent timeline with each run's decision trail. Polls
/// every 2 s while a run is live, 15 s otherwise.
struct SearchesTab: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.detailReduceMotion) private var reduce
    @State private var feed = SearchesFeed()
    @State private var toaster = ActToaster()

    var body: some View {
        let version = store.focusedVersion
        VStack(alignment: .leading, spacing: 9) {
            if !feed.loaded {
                DetailSpinner(size: 20, color: Theme.mut).frame(maxWidth: .infinity).padding(.vertical, 30)
            } else if feed.runs.isEmpty {
                Text("No searches yet for this title. Manual searches, RSS syncs and scheduled sweeps that touch it show up here — each with what it grabbed and why.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mut)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .padding(.horizontal, 20)
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
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
        let live = feed.runs.filter { $0.status == "running" }
        let searching = live.filter { $0.search != nil }
        let other = live.filter { $0.search == nil }
        let recent = TasksLogic.groupRuns(feed.runs.filter { $0.status != "running" })
        ForEach(searching) { run in
            SearchRunCard(run: run) { Task { await feed.load(store.client, itemId: store.itemId) } }
        }
        ForEach(other) { run in
            RunningRow(run: run, queued: run.phase == nil || run.phase == "queued", playful: false, focused: false)
        }
        ForEach(recent) { group in
            RecentGroupView(group: group, tasks: [], playful: false)
        }
    }
}

/// The scoped run feed behind the Searches tab.
@MainActor
@Observable
final class SearchesFeed {
    private(set) var runs: [ActivityRun] = []
    private(set) var loaded = false
    var versionId: Int?
    var tier: QualityTier?
    /// Finished runs never change: their version check is kept.
    @ObservationIgnored private var inScope: [Int: Bool] = [:]
    @ObservationIgnored private var scopedFor: Int?

    var anyRunning: Bool { runs.contains { $0.status == "running" } }

    func load(_ client: APIClient?, itemId: Int) async {
        guard let client else { return }
        guard let page = try? await client.systemRuns(touchedItem: itemId) else { loaded = true; return }
        guard let versionId else {
            runs = page.items
            loaded = true
            return
        }
        if scopedFor != versionId { inScope = [:]; scopedFor = versionId }
        let pending = page.items.filter { inScope[$0.id] == nil || $0.status == "running" }.map(\.id)
        let tier = tier
        let checked = await withTaskGroup(of: (Int, Bool?).self) { group in
            for id in pending {
                group.addTask {
                    guard let detail = try? await client.systemRun(id: id) else { return (id, nil) }
                    return (id, RunVersionScope.runInScope(detail, versionId: versionId, tier: tier))
                }
            }
            var out: [(Int, Bool?)] = []
            for await result in group { out.append(result) }
            return out
        }
        for (id, ok) in checked { if let ok { inScope[id] = ok } }
        runs = page.items.filter { inScope[$0.id] == true }
        loaded = true
    }
}
