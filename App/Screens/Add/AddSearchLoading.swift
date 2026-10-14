import SwiftUI
import FusionhaKit

extension AddTitleSheet {
    // MARK: Loading

    static func missingKey(_ error: Error, _ code: String) -> Bool {
        guard case .http(_, let body) = error as? APIError else { return false }
        return body.contains(code)
    }

    func loadTrending() async {
        guard let client = model.client else { return }
        trendingState = .loading
        do {
            trending = try await client.discover(kind: kind, list: .trending)
            trendingMissingKey = false
            trendingState = .loaded
        } catch {
            if Task.isCancelled { return }
            trendingMissingKey = Self.missingKey(error, "tmdb_not_configured")
            trendingState = .failed
        }
    }

    func search() async {
        guard !term.isEmpty else { searchState = .idle; return }
        searchState = .loading
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled, let client = model.client else { return }
        do {
            if source == .tvdb {
                tvdbResults = try await client.searchTVDB(term: term)
            } else {
                results = try await client.search(term: term, kind: kind)
            }
            searchMissingKey = false
            searchState = .loaded
        } catch {
            if Task.isCancelled { return }
            results = []
            tvdbResults = []
            searchMissingKey = Self.missingKey(error, source == .tvdb ? "tvdb_not_configured" : "tmdb_not_configured")
            searchState = .failed
        }
    }

    // MARK: Screenshots

    #if DEBUG
    /// CI screenshots: open on a trending pick (`…_ADD_PICK=<tmdb id>`, with
    /// `…_ADD_KIND` for one off the list) or a
    /// TVDB-only one (`…_ADD_TVDB=<tvdb id>`); `…_ADD_DETAILS` then pushes
    /// its "View details".
    func screenshotHooks() {
        let env = ProcessInfo.processInfo.environment
        guard flow == nil, let client = model.client else { return }
        if let id = env["FUSIONHA_SCREENSHOT_ADD_PICK"].flatMap(Int.init) {
            Task {
                let list = (try? await client.discover(kind: .all, list: .trending)) ?? []
                var hit = list.first { $0.tmdbId == id }
                if hit == nil, let kind = env["FUSIONHA_SCREENSHOT_ADD_KIND"] {
                    // A title off the trending list (the upcoming movie).
                    hit = try? await client.discoverPreview(kind: kind == "movie" ? .movie : .series, tmdbId: id).asSearchResult
                }
                if let hit = hit ?? list.first {
                    startFlow(.tmdb(MediaSearchResult(copying: hit, inLibrary: false)))
                    if env["FUSIONHA_SCREENSHOT_ADD_DETAILS"] != nil, let flow {
                        try? await Task.sleep(for: .milliseconds(1200))
                        viewDetailsAction(flow)?()
                    }
                }
            }
        } else if let id = env["FUSIONHA_SCREENSHOT_ADD_TVDB"].flatMap(Int.init) {
            Task {
                let list = (try? await client.searchTVDB(term: "monster")) ?? []
                if let hit = list.first(where: { $0.tvdbId == id }) ?? list.first { startFlow(.tvdb(hit)) }
            }
        }
    }
    #endif
}
