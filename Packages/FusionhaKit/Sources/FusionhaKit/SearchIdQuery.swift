import Foundation

/// A search term shaped like an external id (unified search): `tt…`,
/// `imdb:tt…`, `tvdb:N` / `tvdb-N`, `tmdb:N`, or a TMDB / TheTVDB / IMDb link.
/// It goes to `GET /api/v1/search/by-id` and the hit is pinned as "Exact match".
///
/// A bare number is NOT an id here (the server reads one as a TMDB id, but in a
/// title search "1917" or "2012" is a film); type `tmdb:1917` for that.
public struct SearchIdQuery: Equatable, Sendable {
    /// The id in the server's own form (`tt123`, `tvdb:123`, `tmdb:123`).
    public let id: String
    /// The kinds to resolve it as. A TMDB / IMDb id can be a movie or a series,
    /// so both are asked; a TVDB id is always a series.
    public let kinds: [SearchKind]

    public init(id: String, kinds: [SearchKind]) {
        self.id = id
        self.kinds = kinds
    }

    public static func parse(_ raw: String) -> SearchIdQuery? {
        let term = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty, !term.contains(" ") else { return nil }
        let lower = term.lowercased()
        if lower.contains("themoviedb.org") || lower.contains("imdb.com") || lower.contains("thetvdb.com") {
            return parseLink(lower)
        }
        var rest = lower
        if rest.hasPrefix("imdb:") { rest = String(rest.dropFirst(5)) }
        if let imdb = imdbId(rest), imdb == rest { return SearchIdQuery(id: imdb, kinds: [.movie, .series]) }
        for prefix in ["tvdb:", "tvdb-"] where lower.hasPrefix(prefix) {
            let digits = String(lower.dropFirst(prefix.count))
            return isDigits(digits) ? SearchIdQuery(id: "tvdb:\(digits)", kinds: [.series]) : nil
        }
        if lower.hasPrefix("tmdb:") {
            let digits = String(lower.dropFirst(5))
            return isDigits(digits) ? SearchIdQuery(id: "tmdb:\(digits)", kinds: [.movie, .series]) : nil
        }
        return nil
    }

    // MARK: Links

    private static func parseLink(_ url: String) -> SearchIdQuery? {
        let parts = pathParts(url)
        if url.contains("themoviedb.org") {
            // themoviedb.org/movie/693134-dune-part-two, /tv/1399
            guard let i = parts.firstIndex(where: { $0 == "movie" || $0 == "tv" }), i + 1 < parts.count else { return nil }
            let digits = String(parts[i + 1].prefix { $0.isNumber })
            guard !digits.isEmpty else { return nil }
            return SearchIdQuery(id: "tmdb:\(digits)", kinds: [parts[i] == "movie" ? .movie : .series])
        }
        if url.contains("imdb.com") {
            // imdb.com/title/tt15239678/
            guard let i = parts.firstIndex(of: "title"), i + 1 < parts.count, let imdb = imdbId(parts[i + 1]) else { return nil }
            return SearchIdQuery(id: imdb, kinds: [.movie, .series])
        }
        // thetvdb.com/?tab=series&id=81189, /dereferrer/series/81189, /series/81189
        if let id = queryValue("id", in: url), isDigits(id) {
            return SearchIdQuery(id: "tvdb:\(id)", kinds: [.series])
        }
        if let i = parts.firstIndex(of: "series"), i + 1 < parts.count, isDigits(parts[i + 1]) {
            return SearchIdQuery(id: "tvdb:\(parts[i + 1])", kinds: [.series])
        }
        // A slug link (thetvdb.com/series/breaking-bad) names no id.
        return nil
    }

    private static func pathParts(_ url: String) -> [String] {
        var s = url
        if let scheme = s.range(of: "://") { s = String(s[scheme.upperBound...]) }
        if let q = s.firstIndex(where: { $0 == "?" || $0 == "#" }) { s = String(s[..<q]) }
        return s.split(separator: "/").map(String.init)
    }

    private static func queryValue(_ name: String, in url: String) -> String? {
        guard let q = url.firstIndex(of: "?") else { return nil }
        for pair in url[url.index(after: q)...].split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if kv.count == 2, kv[0] == name { return kv[1] }
        }
        return nil
    }

    /// `tt` followed by digits at the start of `s`, e.g. `tt0903747`.
    private static func imdbId(_ s: String) -> String? {
        guard s.hasPrefix("tt") else { return nil }
        let digits = String(s.dropFirst(2).prefix { $0.isNumber })
        return digits.isEmpty ? nil : "tt" + digits
    }

    private static func isDigits(_ s: String) -> Bool {
        !s.isEmpty && s.allSatisfy { $0.isASCII && $0.isNumber }
    }
}
