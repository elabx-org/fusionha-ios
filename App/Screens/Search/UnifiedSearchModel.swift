import SwiftUI
import FusionhaKit

/// The unified search's provider side (owner-approved 2026-10-23): the add lane
/// runs as you type, ~300 ms after the last keystroke, through a
/// `UnifiedSearchSource` (today the client fan-out over TMDB, TheTVDB and the id
/// lookup). Each provider's rows land as it answers; a new term cancels the
/// calls still in flight. The owned lane stays local and instant (`OwnedSearch`).
@MainActor
@Observable
final class UnifiedSearchModel {
    /// The provider side for `term`.
    private(set) var lanes = UnifiedSearchLanes()
    /// The term `lanes` belongs to ("" before the first answer).
    private(set) var term = ""
    /// Bumped when a provider's rows land, so rows can stagger in per arrival.
    private(set) var arrival = 0

    var searching: Bool { !lanes.isSettled }

    /// Runs one term to completion (call from `.task(id: term)`; cancelling the
    /// task cancels the provider calls).
    func run(_ term: String, source: (any UnifiedSearchSource)?, motion: Bool) async {
        guard !term.isEmpty, let source else {
            reset()
            return
        }
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        var first = true
        for await next in source.lanes(for: term) {
            guard !Task.isCancelled else { return }
            withAnimation(motion ? .spring(duration: 0.35, bounce: 0) : .easeInOut(duration: 0.2)) {
                if first {
                    self.term = term
                    first = false
                }
                lanes = next
                arrival += 1
            }
        }
    }

    func reset() {
        lanes = UnifiedSearchLanes()
        term = ""
    }

    /// Answers for `current` (stale lanes for an older term are not shown).
    func isCurrent(_ current: String) -> Bool { term == current }
}
