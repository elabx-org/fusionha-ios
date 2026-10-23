import Foundation

// The Watchlists & lists page's view of every source (web `source-model.ts`
// and `detail-data.ts`, fusionha 0.4.226): order and state from the summary
// (server truth), names, minis and options from the Letterboxd and Plex reads
// joined by the stable id.

public enum AutoSourceKind: String, Sendable, Hashable {
    case diary
    case ownWatchlist = "own_watchlist"
    case watchlist, list
    case plexWatchlist = "plex_watchlist"
    case plexList = "plex_list"
}

/// One source row and the detail behind it.
public struct AutoSourceView: Sendable, Hashable, Identifiable {
    public let source: AutoSource
    public let name: String
    /// "@user", or nil.
    public let owner: String?
    /// "7 requested · 23 baseline".
    public let mini: String
    public let kind: AutoSourceKind
    /// The integer request-source row id (nil for placeholders and Plex).
    public let rowId: Int?
    public let lb: LbSource?
    public let plex: PlexWatchlistRead?
    public let plexList: PlexListSource?

    public var id: String { source.sourceId }
    public var sourceId: String { source.sourceId }
    public var state: AutoSourceState { source.state }
    public var needsReview: Int { source.needsReview }
    public var isPlex: Bool { kind == .plexWatchlist || kind == .plexList || source.group == .plex }
    /// "Letterboxd" or "Plex": the Pick sheet's provider word.
    public var provider: String { isPlex ? "Plex" : "Letterboxd" }

    /// `owner · mini · N to review` (the review part is the row's amber tail).
    public var subtitle: String { [owner, mini.isEmpty ? nil : mini].compactMap { $0 }.joined(separator: " · ") }
    public var reviewText: String? { needsReview > 0 ? "\(needsReview) to review" : nil }
}

public enum AutoSourceViews {
    /// Rows in summary order. `lbUnread` / `plexUnread`: that read has not
    /// answered, so minis stay empty instead of saying "Connect…".
    public static func build(_ summary: AutoSummary, letterboxd: LetterboxdRead?, sources: [LbSource],
                             plex: PlexWatchlistRead?, lbUnread: Bool = false, plexUnread: Bool = false) -> [AutoSourceView] {
        let byId = Dictionary(sources.map { ($0.sourceId, $0) }, uniquingKeysWith: { a, _ in a })
        return summary.sources.map { s in
            view(s, letterboxd: letterboxd, row: byId[s.sourceId], plex: plex, lbUnread: lbUnread, plexUnread: plexUnread)
        }
    }

    static func view(_ s: AutoSource, letterboxd lb: LetterboxdRead?, row: LbSource?, plex: PlexWatchlistRead?,
                     lbUnread: Bool, plexUnread: Bool) -> AutoSourceView {
        let at = lb?.username.map { "@\($0)" }
        func make(_ name: String, _ owner: String?, _ mini: String, _ kind: AutoSourceKind, _ rowId: Int?,
                  plex: PlexWatchlistRead? = nil, list: PlexListSource? = nil) -> AutoSourceView {
            AutoSourceView(source: s, name: name, owner: owner, mini: mini, kind: kind, rowId: rowId,
                           lb: row, plex: plex, plexList: list)
        }
        switch s.sourceId {
        case "letterboxd-diary":
            guard let d = lb?.diary else {
                return make("Diary", at, lbUnread ? "" : "Connect your Letterboxd", .diary, nil)
            }
            return make("Diary", at, lbMini(d.counts?.requested ?? d.requestedCount, d.counts?.baseline), .diary, row?.id)
        case "letterboxd-watchlist":
            let f = lb.map(\.watchlistFollow).flatMap { $0.sourceKey == s.sourceId ? $0 : nil }
            let n = f.map { $0.counts?.requested ?? $0.requestedCount } ?? row?.requestedCount ?? 0
            let mini = f != nil || row != nil ? requested(n) : (lbUnread ? "" : "Connect your Letterboxd")
            return make("My watchlist", at, mini, .ownWatchlist, f?.sourceId ?? row?.id)
        case "plex-watchlist":
            let signIn = s.state == .needsSignIn || s.state == .notConnected
            let mini = plexUnread ? "" : (signIn && plex?.enabled != true ? "Sign in with Plex to use it" : requested(plex?.requestedCount ?? 0))
            return make("Plex watchlist", nil, mini, .plexWatchlist, nil, plex: plex)
        default:
            if let row { return linked(s, row) }
            if let list = plex?.lists.sources.first(where: { $0.sourceId == s.sourceId }) {
                let n = list.counts?.requested ?? list.requestedCount
                let mini = list.itemCount.map { "\(requested(n)) · \($0) titles" } ?? requested(n)
                return make(list.name, nil, mini, .plexList, nil, plex: plex, list: list)
            }
            let isPlex = s.group == .plex
            return make(isPlex ? "Plex list" : "Letterboxd list", nil, "", isPlex ? .plexList : .list, nil)
        }
    }

    static func linked(_ s: AutoSource, _ row: LbSource) -> AutoSourceView {
        let owner = row.owner.map { "@\($0)" }
        let isWatch = row.kind == "LETTERBOXD_WATCHLIST"
        let name = isWatch ? "\(owner ?? "Someone")’s watchlist" : (row.label ?? "List")
        return AutoSourceView(source: s, name: name, owner: isWatch ? nil : owner,
                              mini: lbMini(row.counts?.requested ?? row.requestedCount, row.counts?.baseline),
                              kind: isWatch ? .watchlist : .list, rowId: row.id, lb: row, plex: nil, plexList: nil)
    }

    static func requested(_ n: Int) -> String { "\(n) requested" }

    static func lbMini(_ n: Int, _ baseline: Int?) -> String {
        guard let baseline, baseline > 0 else { return requested(n) }
        return "\(requested(n)) · \(baseline) baseline"
    }

    /// The group's quiet meta (web `metaOf`).
    public static func groupMeta(_ group: AutoSourceGroup, _ rows: [AutoSourceView]) -> String? {
        switch group {
        case .letterboxd:
            return rows.compactMap(\.owner).first.map { "\($0) · public data only" } ?? "not connected"
        case .plex:
            switch rows.first(where: { $0.kind == .plexWatchlist })?.state {
            case .notConnected?: return "not connected"
            case .needsSignIn?: return "sign in again"
            default: return "connected"
            }
        case .lists:
            return nil
        }
    }
}

/// What the detail shows, from whichever read backs the source (web `detailData`).
public struct AutoSourceDetail: Sendable, Hashable {
    public var enabled = false
    public var sync: SourceSync?
    public var counts: SourceCounts = .empty
    public var requested = 0
    public var lastCheckedAt: String?
    public var nextCheckAt: String?
    public var lastError: String?
    public var unmatched = 0
    /// `new` or `existing`.
    public var baseline = "new"
    public var itemCount: Int?
    public var url: String?
    public var uhd = false
    public var rewatch = false

    public init(_ v: AutoSourceView) {
        if v.kind == .plexWatchlist, let p = v.plex {
            enabled = p.enabled; sync = p.sync; counts = p.counts ?? .empty
            requested = p.counts?.requested ?? p.requestedCount
            lastCheckedAt = p.lastCheckedAt; nextCheckAt = p.nextCheckAt; lastError = p.lastError
            unmatched = p.unmatchedCount; baseline = SourceDetailCopy.baseline(p.firstCheck?.baseline)
            itemCount = p.itemCount; uhd = p.alsoUhd
        } else if v.kind == .plexList, let l = v.plexList {
            enabled = l.enabled; sync = l.sync; counts = l.counts ?? .empty
            requested = l.counts?.requested ?? l.requestedCount
            lastCheckedAt = l.lastCheckedAt; lastError = l.error
            unmatched = l.unmatchedCount; baseline = SourceDetailCopy.baseline(l.baseline); itemCount = l.itemCount
        } else if let r = v.lb {
            enabled = r.enabled; sync = r.sync; counts = r.counts ?? .empty
            requested = r.counts?.requested ?? r.requestedCount
            lastCheckedAt = r.lastCheckedAt; nextCheckAt = r.nextCheckAt; lastError = r.lastError
            unmatched = r.unmatchedCount; baseline = SourceDetailCopy.baseline(r.baseline)
            itemCount = r.itemCount; url = r.url; uhd = r.alsoUhd
        }
    }

    /// "1 queued · working through them · 605 films read".
    public func hint(ownWatchlist: Bool) -> String? {
        let parts = [SyncProgress.queuedHint(counts), ownWatchlist ? itemCount.map { "\($0) films read" } : nil].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// Where Watchlists & lists opens from and what the open Duo's Account shows.
public enum WatchlistsRoute {
    /// `fusionha://account/lists` and `account/lists/<source-id>`: the page,
    /// and the source to open on it. nil when the link isn't for the page.
    public static func parse(host: String?, path: [String]) -> String?? {
        guard host == "account", path.first == "lists" else { return nil }
        return .some(path.count > 1 ? path[1] : nil)
    }

    /// The Account right page on the open Duo (Spread): Watchlists & lists
    /// when something needs review, else Sign-in methods.
    public static func spreadOpensLists(_ summary: AutoSummary?) -> Bool {
        (summary?.needsReview ?? 0) > 0
    }
}
