import SwiftUI
import FusionhaKit

/// One "Pick the right title" session (web `use-pick-queue.ts`, `use-pick.ts`):
/// the source's unmatched titles one after another ("2 of 3"), the TMDB search
/// for the one under review, Request it and Ignore. Closes when none remain.
@MainActor
@Observable
final class PickTitleModel {
    let sourceId: String
    var items: [UnmatchedItem] = []
    var loaded = false
    var loadFailed = false
    private(set) var handled = 0
    private var total: Int?
    var term = ""
    var kind: SearchKind = .all
    var results: [MediaSearchResult] = []
    var searching = false
    var searchFailed = false
    var picked: MediaSearchResult?
    /// A refusal kept in the sheet (Ignore is still offered).
    var blocked: PickCopy.Refusal?
    var busy = false
    /// Set when nothing is left to review: the sheet closes.
    var finished = false

    init(sourceId: String) { self.sourceId = sourceId }

    var item: UnmatchedItem? { items.first }

    /// "2 of 3" while more than one was offered.
    var position: String? {
        guard let total, total > 1 else { return nil }
        return PickCopy.position(handled + 1, of: total)
    }

    var searchKey: String { "\(item?.itemId ?? 0)|\(kind.rawValue)|\(term)" }

    func load(_ client: APIClient?) async {
        guard let client else { return }
        do {
            items = try await client.unmatchedItems(sourceId)
            total = items.count
            loaded = true
            startItem()
        } catch {
            loadFailed = true
        }
    }

    private func startItem() {
        guard let item else {
            finished = true
            return
        }
        term = item.query.isEmpty ? item.title : item.query
        picked = nil
        blocked = nil
        results = []
    }

    /// Debounced by the caller's `task(id: searchKey)`.
    func search(_ client: APIClient?) async {
        let text = term.trimmingCharacters(in: .whitespaces)
        guard let client, !text.isEmpty else {
            results = []
            return
        }
        searching = true
        defer { searching = false }
        do {
            results = try await client.search(term: text, kind: kind)
            searchFailed = false
            if let picked, !results.contains(picked) { self.picked = nil }
        } catch is CancellationError {
        } catch {
            if (error as? URLError)?.code == .cancelled { return }
            searchFailed = true
        }
    }

    func request(_ model: AppModel) async {
        guard let client = model.client, let item, let picked, !busy else { return }
        busy = true
        blocked = nil
        defer { busy = false }
        do {
            let result = try await client.resolveUnmatched(sourceId, itemId: item.itemId, tmdbId: picked.tmdbId, kind: picked.kind)
            model.toast(result.queued ? PickCopy.queued : PickCopy.done(result.outcome, title: item.label))
            next()
        } catch {
            let refusal = PickCopy.Refusal(error)
            switch refusal {
            case .handled:
                model.toast(refusal.toast, variant: .info)
                next()
            case .failed:
                model.toast(refusal.toast, variant: .error)
            default:
                blocked = refusal
            }
        }
    }

    func ignore(_ model: AppModel) async {
        guard let client = model.client, let item, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            try await client.ignoreUnmatched(sourceId, itemId: item.itemId)
            model.toast(PickCopy.ignored)
            next()
        } catch {
            let refusal = PickCopy.Refusal(error)
            model.toast(refusal == .handled ? refusal.toast : PickCopy.failed, variant: refusal == .handled ? .info : .error)
            if refusal == .handled { next() }
        }
    }

    private func next() {
        guard !items.isEmpty else { return }
        items.removeFirst()
        handled += 1
        startItem()
    }
}
