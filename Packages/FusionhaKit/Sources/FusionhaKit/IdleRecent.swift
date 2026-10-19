import Foundation

// MARK: - Recently finished (web `idle-derive.ts` → `deriveRecent`)

/// One finished import; a season pack landing as N history rows is one row.
public struct FinishedRow: Sendable, Hashable, Identifiable {
    public let key: String
    public let itemId: Int?
    public let title: String
    public let posterUrl: String?
    /// `S02E02 · E05`, `S02E01–E06`, a movie's year, or empty.
    public let label: String
    public let tier: QualityTier?
    public let quality: String
    /// Range · audio · edition, then the release group.
    public let extra: String
    /// The newest import's server timestamp.
    public let at: String
    public let count: Int
    public var id: String { key }
}

public enum IdleRecent {
    /// Rows the phone (and any width below the two-column layout) shows.
    public static let narrowLimit = 6
    /// The most rows the desktop balance ever asks for (`RECENT_MAX`).
    public static let max = 16
    /// History page fetched for the card (`RECENT_PAGE_SIZE`).
    public static let pageSize = 100

    private static let extraKinds: Set<String> = ["range", "audio", "edition", "group"]

    /// History is newest first: fold consecutive imports of one version into one
    /// row and keep the newest `limit`.
    public static func derive(_ items: [HistoryEntry], limit: Int = narrowLimit) -> [FinishedRow] {
        var groups: [[HistoryEntry]] = []
        for h in items where h.eventType.uppercased() == "IMPORTED" {
            if let head = groups.last?.first, head.mediaItemId == h.mediaItemId, head.editionId == h.editionId {
                groups[groups.count - 1].append(h)
            } else {
                groups.append([h])
            }
        }
        return groups.prefix(limit).map { g in
            let head = g[0]
            let chips = (head.chips ?? []).filter { extraKinds.contains($0.kind) }
            let extra = chips.filter { $0.kind != "group" } + chips.filter { $0.kind == "group" }
            return FinishedRow(
                key: String(head.id), itemId: head.mediaItemId,
                title: head.itemTitle ?? head.sourceTitle ?? "Untitled", posterUrl: head.posterUrl,
                label: label(g), tier: head.tier,
                quality: head.quality.map(QualityLabels.text) ?? "",
                extra: extra.map(\.label).joined(separator: " · "),
                at: head.createdAt, count: g.count)
        }
    }

    /// Episode codes from the release names, or the movie's year from its path.
    static func label(_ group: [HistoryEntry]) -> String {
        let eps = group.compactMap { episode(in: $0.sourceTitle ?? "") }
        if let season = eps.first?.s {
            let same = eps.filter { $0.s == season }
            let base = IdleComingUp.episodeRange(season: season, episodes: same.map(\.e))
            return same.count < eps.count ? "\(base) +\(eps.count - same.count)" : base
        }
        guard let path = group.first?.data?["relative_path"]?.text,
              let m = path.range(of: #"\((\d{4})\)"#, options: .regularExpression) else { return "" }
        return String(path[m].dropFirst().dropLast())
    }

    private static func episode(in title: String) -> (s: Int, e: Int)? {
        guard let regex = try? NSRegularExpression(pattern: #"S(\d{1,2})E(\d{1,3})"#, options: .caseInsensitive),
              let m = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
              let sr = Range(m.range(at: 1), in: title), let er = Range(m.range(at: 2), in: title),
              let s = Int(title[sr]), let e = Int(title[er]) else { return nil }
        return (s, e)
    }
}

/// THE `QualityName` → display label table (web `lib/quality-labels.ts`,
/// mirroring the backend's `QUALITY_FULL_LABELS`): the arr / TRaSH spelling.
public enum QualityLabels {
    static let labels: [String: String] = [
        "REMUX_2160P": "Bluray-2160p Remux", "BLURAY_2160P": "Bluray-2160p", "WEBDL_2160P": "WEBDL-2160p",
        "WEBRIP_2160P": "WEBRip-2160p", "HDTV_2160P": "HDTV-2160p", "REMUX_1080P": "Bluray-1080p Remux",
        "BLURAY_1080P": "Bluray-1080p", "WEBDL_1080P": "WEBDL-1080p", "WEBRIP_1080P": "WEBRip-1080p",
        "RAWHD": "Raw-HD", "HDTV_1080P": "HDTV-1080p", "BLURAY_720P": "Bluray-720p", "WEBDL_720P": "WEBDL-720p",
        "WEBRIP_720P": "WEBRip-720p", "HDTV_720P": "HDTV-720p", "BLURAY_576P": "Bluray-576p",
        "BLURAY_480P": "Bluray-480p", "DVD": "DVD", "DVDR": "DVD-R", "WEBDL_480P": "WEBDL-480p",
        "WEBRIP_480P": "WEBRip-480p", "SDTV": "SDTV", "BRDISK": "BR-DISK", "DVDSCR": "DVDSCR",
        "REGIONAL": "REGIONAL", "TELECINE": "TELECINE", "TELESYNC": "TELESYNC", "CAM": "CAM",
        "WORKPRINT": "WORKPRINT", "UNKNOWN": "Unknown",
    ]

    public static func text(_ raw: String) -> String { labels[raw] ?? raw }
}
