import SwiftUI
import FusionhaKit

/// A title the Preview page shows (`/preview/{kind}/{tmdbId}`).
struct PreviewRoute: Identifiable, Hashable {
    let kind: PreviewKind
    let tmdbId: Int
    var id: String { "\(kind.rawValue)-\(tmdbId)" }

    init(kind: PreviewKind, tmdbId: Int) {
        self.kind = kind
        self.tmdbId = tmdbId
    }

    init(_ result: MediaSearchResult) {
        self.init(kind: result.previewKind, tmdbId: result.tmdbId)
    }
}

/// The Discover "Add as" provider override. Session memory only, like the web.
@MainActor
@Observable
final class DiscoverSession {
    static let shared = DiscoverSession()
    /// `auto` (the Settings default), `tmdb`, `tvdb` or `hybrid`.
    var providerOverride = "auto"
    /// `GET /api/v1/settings` → `metadata_provider`.
    var globalProvider = "tmdb"
    /// `GET /api/v1/settings` → `animations_enabled` (the web's app-wide motion switch).
    var animationsEnabled = true

    var effectiveProvider: String { providerOverride == "auto" ? globalProvider : providerOverride }
}

/// Shared state for one Discover page: request statuses for the card chips,
/// the pending count and the sheets the cards open.
@MainActor
@Observable
final class DiscoverStore {
    var requests: [MediaRequest] = []
    var requestsLoaded = false
    var requestsFailed = false
    var pendingCount = 0
    /// Open issues and those needing an admin, for issue managers (Proposal 2).
    var issueCounts = IssueCounts()
    /// The server has no TMDB key: `tmdb_configured: false` in the settings, or
    /// a rail answered 409 `tmdb_not_configured` (web `tmdbMissing`). Browse
    /// shows one `KeyMissingNotice` instead of every rail failing.
    var tmdbMissing = false
    /// The Requests view to open next (`?tab=issues` lands on Issues).
    var requestsPane: RequestsPane?
    var preview: PreviewRoute?
    var requestPick: MediaSearchResult?
    var trailer: TrailerResult?
    var collection: CollectionSummary?
    /// Bumped to refetch the collections rail after an ignore/add.
    var collectionsVersion = 0
    /// An id inside Discover's scroll view to bring to the top (the Board's
    /// summary jumps to a stage this way); cleared once scrolled.
    var scrollTo: String?
    /// An id to bring just into view, scrolling as little as it takes (the
    /// Inbox list's J / K focus, web `reveal`); cleared once scrolled.
    var scrollReveal: String?
    /// Bumped to refetch request lists after a decision.
    var requestsVersion = 0 {
        didSet { demand.reset() }
    }
    /// Per-title demand for a requester's cards (Me too, Watch).
    let demand = DiscoverDemand()

    /// The highest-priority request status per TMDB id (pending > approved > …).
    var statusByTmdb: [Int: String] {
        var map: [Int: String] = [:]
        for request in requests {
            if let current = map[request.tmdbId],
               MediaRequest.priority(current) >= MediaRequest.priority(request.status) { continue }
            map[request.tmdbId] = request.status
        }
        return map
    }

    /// A rail's load failed: a 409 `tmdb_not_configured` flips Browse to the notice.
    func railFailed(_ error: Error) {
        if case .http(_, let body)? = error as? APIError, body.contains("tmdb_not_configured") { tmdbMissing = true }
    }

    func loadRequests(_ client: APIClient?, approver: Bool, issues: Bool = false) async {
        guard let client else { return }
        do {
            requests = try await client.requests(status: nil)
            requestsFailed = false
        } catch {
            requestsFailed = true
        }
        requestsLoaded = true
        // `needs_you` (0.4.220) counts both for us; older servers by hand.
        var needsYou: RequestNeedsYou?
        if approver || issues { needsYou = (try? await client.requestCounts(view: "all"))?.needsYou }
        if approver {
            if let needsYou {
                pendingCount = needsYou.requests
            } else {
                pendingCount = (try? await client.requests(status: "pending").count)
                    ?? requests.filter { $0.status == "pending" }.count
            }
        } else {
            pendingCount = 0
        }
        if issues, let needsYou {
            issueCounts = IssueCounts(open: needsYou.openIssues, needYou: needsYou.issues)
        } else if issues, let page = try? await client.adminThreads(type: "issue", state: "OPEN") {
            issueCounts = IssueCounts.of(page.items)
        } else if !issues {
            issueCounts = IssueCounts()
        }
    }
}
