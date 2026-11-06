import SwiftUI
import FusionhaKit

/// v2's automatic searches: the same store calls as v1 (and the same
/// toasts), plus the state the control that started one shows in place:
/// "Searching…" at once, the outcome for a few seconds, then normal.
/// A second tap while one runs on the same target does nothing.
extension DetailStore {
    /// How long an outcome stays in place before the control is back to normal.
    static let searchOutcomeSeconds: Double = 4

    func activity(_ target: SearchTarget) -> SearchActivity? { searchActivity.activity(target) }
    /// A season header's line: Search season, Search each episode or Search missing.
    func seasonActivity(_ season: Int) -> SearchActivity? {
        searchActivity.activity(any: [.season(season), .seasonMissing(season)])
    }

    /// A scoped automatic search (`search(label:…)`) for this target.
    func v2Search(_ target: SearchTarget, label: String, editionId: Int? = nil, season: Int? = nil,
                  episodeId: Int? = nil, missingOnly: Bool = false) {
        run(target) { store in
            let decisions = await store.search(label: label, editionId: editionId, season: season,
                                               episodeId: episodeId, missingOnly: missingOnly)
            return decisions.map(DetailStore.grabbedVersions)
        }
    }

    /// A one-at-a-time season search (`gradualSearch`) for this target.
    func v2GradualSearch(_ target: SearchTarget, label: String, season: Int, missingOnly: Bool) {
        run(target) { store in
            await store.gradualSearch(label: label, season: season, missingOnly: missingOnly)
        }
    }

    /// Begins the run synchronously (so the tap's own frame shows it), then
    /// writes its outcome and clears it later. `work` returns what it grabbed,
    /// nil when the request failed.
    private func run(_ target: SearchTarget, _ work: @escaping @MainActor (DetailStore) async -> Int?) {
        guard let token = searchActivity.begin(target) else { return }
        announce(.searching)
        Task { [weak self] in
            guard let self else { return }
            let outcome = SearchActivity.outcome(grabbed: await work(self))
            searchActivity.finish(target, token: token, outcome)
            announce(outcome)
            try? await Task.sleep(for: .seconds(Self.searchOutcomeSeconds))
            searchActivity.clear(target, token: token)
        }
    }

    private func announce(_ activity: SearchActivity) {
        AccessibilityNotification.Announcement(activity.spoken).post()
    }

    /// Releases grabbed, counted per version like the toast.
    nonisolated private static func grabbedVersions(_ decisions: [SearchDecision]) -> Int {
        let grabbed = decisions.filter(\.grabbed)
        guard !grabbed.isEmpty else { return 0 }
        return max(Set(grabbed.compactMap(\.editionId)).count, 1)
    }
}
