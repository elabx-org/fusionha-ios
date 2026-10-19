import Foundation
import Observation
import FusionhaKit

/// The state and calls of one interactive search (InteractiveSearch.tsx),
/// shared by the standalone sheet and the episode sheet's Search tab.
@MainActor
@Observable
final class InteractiveSearchModel {
    let store: DetailStore
    let target: InteractiveTarget

    var editionId = 0
    var results: [Int: [ReleasePreview]] = [:]
    var failures: [Int: String] = [:]
    var inFlight: Set<Int> = []
    var searchedAt: [Int: Date] = [:]
    var scopeStatus: [Int: ReleaseScopeStatus] = [:]
    var cooldown: [IndexerUnavailable] = []
    var filters = ReleaseFilters()
    var grabbed: Set<String> = []
    var triggers: [String: String] = [:]
    var toast: SearchToast?
    var grabSuccess = 0
    private var started = false

    init(store: DetailStore, target: InteractiveTarget) {
        self.store = store
        self.target = target
    }

    /// Every edition of the item: the toggle (web passes them all, so a scoped
    /// search can still flip HD ↔ 4K).
    var editions: [DetailEdition] { store.detail?.orderedEditions ?? [] }
    var edition: DetailEdition? { editions.first { $0.id == editionId } }
    var heading: String {
        guard let title = store.detail?.title else { return target.subtitle }
        return target.subtitle.isEmpty ? title : "\(title) · \(target.subtitle)"
    }

    var rows: [ReleasePreview] { results[editionId] ?? [] }
    var scanning: Bool { inFlight.contains(editionId) || (results[editionId] == nil && failures[editionId] == nil) }
    var failed: Bool { !scanning && failures[editionId] != nil }

    // MARK: Loading

    func start() async {
        guard !started else { return }
        started = true
        let first = target.editionIds.first ?? editions.first?.id ?? 0
        editionId = first
        // "All versions" chosen → every version is searched up front (the web's searchBoth).
        var seed = target.editionIds.count > 1 ? target.editionIds : [first]
        applyScreenshotState()
        if !seed.contains(editionId) { seed.append(editionId) }
        let now = Date()
        for id in seed { searchedAt[id] = now }
        for id in seed where id != editionId { Task { await load(id) } }
        Task { await loadCooldown() }
        await load(editionId)
    }

    func selectEdition(_ id: Int) {
        guard id != editionId else { return }
        editionId = id
        if searchedAt[id] == nil { searchedAt[id] = Date() }
        if results[id] == nil && !inFlight.contains(id) { Task { await load(id) } }
    }

    func refresh() async {
        await load(editionId)
        searchedAt[editionId] = Date()
    }

    func load(_ id: Int) async {
        guard let client = store.client, id != 0, !inFlight.contains(id) else { return }
        #if DEBUG
        if screenshotView == "loading" { return }
        #endif
        inFlight.insert(id)
        defer { inFlight.remove(id) }
        do {
            let releases = try await client.releases(itemId: store.itemId, editionId: id,
                                                      episodeId: target.episodeId, seasonNumber: target.seasonNumber)
            failures[id] = nil
            results[id] = releases
            #if DEBUG
            if screenshotView == "grabbed", id == editionId, let first = filters.apply(releases).first {
                await grab(first)
            }
            #endif
        } catch is CancellationError {
            return
        } catch {
            if (error as? URLError)?.code == .cancelled { return }
            failures[id] = Self.describe(error)
        }
    }

    func loadScopeStatus() async {
        guard let client = store.client, editionId != 0 else { return }
        if let status = try? await client.releaseScopeStatus(itemId: store.itemId, editionId: editionId,
                                                              episodeId: target.episodeId, seasonNumber: target.seasonNumber) {
            scopeStatus[editionId] = status
        }
    }

    private func loadCooldown() async {
        guard let client = store.client else { return }
        cooldown = (try? await client.unavailableIndexers())?.items ?? []
    }

    /// A short, readable cause under the failure banner.
    static func describe(_ error: Error) -> String {
        if let url = error as? URLError {
            return url.code == .timedOut ? "The indexers took too long to answer." : url.localizedDescription
        }
        if case APIError.http(let status, _) = error {
            return detail(error) ?? "The server answered HTTP \(status)."
        }
        if error is DecodingError { return "The server's answer couldn't be read." }
        return error.localizedDescription
    }

    /// The backend's `detail` message on an HTTP error, if it sent one.
    static func detail(_ error: Error) -> String? {
        guard case APIError.http(_, let body) = error,
              let json = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any] else { return nil }
        return json["detail"] as? String
    }

    // MARK: Grab

    /// Optimistic like the web: the row flips to Downloading at once, a real
    /// failure reverts it (unless the server says it's already downloading).
    /// A blocklisted release grabs with the override that lifts the blocklist.
    func grab(_ release: ReleasePreview) async {
        guard let client = store.client, !grabbed.contains(release.guid) else { return }
        let guid = release.guid
        let override = release.blocklisted == true
        grabbed.insert(guid)
        triggers[guid] = override ? "forced" : "interactive"
        do {
            let response = try await client.grab(itemId: store.itemId, ReleaseGrabRequest(
                release: release, editionId: editionId, episodeId: target.episodeId,
                seasonNumber: target.seasonNumber, override: override))
            if let trigger = response.grabTrigger { triggers[guid] = trigger }
            grabSuccess += 1
            toast = SearchToast(text: override ? "Grabbed anyway — removed from blocklist" : "Sent to download client")
            await store.reload()
        } catch {
            let message = Self.detail(error)
            let inFlightAlready = message?.range(of: "already (downloading|grabbed)", options: [.regularExpression, .caseInsensitive]) != nil
            if !inFlightAlready {
                grabbed.remove(guid)
                triggers[guid] = nil
            }
            toast = SearchToast(text: message ?? "Grab failed")
        }
    }

    // MARK: Screenshots

    #if DEBUG
    var screenshotView: String? { ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_SEARCH_VIEW"] }
    #endif

    private func applyScreenshotState() {
        #if DEBUG
        switch screenshotView {
        case "4k":
            if let uhd = editions.first(where: { $0.tier == .uhd }) { editionId = uhd.id }
        case "rejected": filters.hideRejected = false
        case "nomatch": filters.keyword = "director's cut"
        default: break
        }
        #endif
    }

    func screenshotAnchor(_ visible: [ReleasePreview]) -> String? {
        #if DEBUG
        guard screenshotView == "rejected" else { return nil }
        return visible.first(where: \.rejected)?.guid
        #else
        return nil
        #endif
    }
}
