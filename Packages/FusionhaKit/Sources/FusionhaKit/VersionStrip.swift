import Foundation

// The title page's version strip (D4, owner-approved with the web session):
// one chip per TRACKED version under the hero's title and meta line, e.g.
// `HD · 1080p`, `4K · 2160p Remux · Director's Cut`, `4K · wanted`. Untracked
// tiers are not shown. Same data as the Versions panel; no new API.

/// One chip of the version strip.
public struct VersionStripChip: Hashable, Sendable, Identifiable {
    public let editionId: Int
    public let tier: QualityTier
    /// Tier, current file quality, then the edition when it isn't Standard.
    public let title: String
    /// The trailing state word: `42%`, `wanted`, `missing 3`, `needs you`; nil when done.
    public let detail: String?
    /// The status the chip is tinted by (`EditionStatus.color`); held reads `.stuck`.
    public let status: EditionStatus
    public let held: Bool

    public var id: Int { editionId }
    /// The chip's whole text: `HD · 1080p · 42%`.
    public var text: String { detail.map { "\(title) · \($0)" } ?? title }

    public init(editionId: Int, tier: QualityTier, edition: String, qualityCode: String?,
                status: VersionStatusDisplay, progress: Double?, held: Bool) {
        self.editionId = editionId
        self.tier = tier
        self.held = held
        var parts = [VersionStrip.tierWord(tier)]
        if let q = VersionStrip.quality(qualityCode) { parts.append(q) }
        if !edition.isEmpty { parts.append(edition) }
        title = parts.joined(separator: " · ")
        self.status = held ? .stuck : status.key
        detail = VersionStrip.detail(status: status, progress: progress, held: held)
    }
}

public enum VersionStrip {
    /// `HD` / `4K`: the tier as the strip names it.
    public static func tierWord(_ tier: QualityTier) -> String { tier == .hd ? "HD" : "4K" }

    /// A quality code as the strip shows it: `REMUX_2160P` → `2160p Remux`,
    /// `WEBDL_1080P` → `1080p`; codes without a resolution keep their label
    /// (`DVD`). Nil for no code or `UNKNOWN`.
    public static func quality(_ code: String?) -> String? {
        guard let code, !code.isEmpty, code != "UNKNOWN" else { return nil }
        guard let res = DetailText.resolution(code) else { return DetailText.quality(code) }
        return code.hasPrefix("REMUX") ? "\(res) Remux" : res
    }

    /// The trailing word: held → `needs you`; downloading / upgrading → the
    /// queue's percent when known; done → nil; else the panel's status word.
    public static func detail(status: VersionStatusDisplay, progress: Double?, held: Bool) -> String? {
        if held { return "needs you" }
        switch status.key {
        case .downloaded:
            return nil
        case .downloading, .upgrading:
            if let progress, progress.isFinite {
                let pct = "\(Int(min(max(progress, 0), 100).rounded()))%"
                return status.key == .upgrading ? "upgrading \(pct)" : pct
            }
            return status.text.lowercased()
        default:
            return status.text.lowercased()
        }
    }

    /// The quality a version's current files carry: a movie's file, or the
    /// most common one across a series version's episode files (ties go to the
    /// first seen, in season / episode order).
    public static func qualityCode(_ detail: ItemDetail, edition: DetailEdition) -> String? {
        guard detail.isSeries else { return edition.movieFile?.quality }
        var counts: [String: Int] = [:]
        var order: [String] = []
        for season in detail.seasonsAscending {
            for ep in season.episodes.sorted(by: { $0.episodeNumber < $1.episodeNumber }) {
                guard let q = ep.file(for: edition.id)?.quality, !q.isEmpty else { continue }
                if counts[q] == nil { order.append(q) }
                counts[q, default: 0] += 1
            }
        }
        return order.max { a, b in
            let ca = counts[a] ?? 0, cb = counts[b] ?? 0
            if ca != cb { return ca < cb }
            // Same count: the earlier one wins.
            return (order.firstIndex(of: a) ?? 0) > (order.firstIndex(of: b) ?? 0)
        }
    }

    /// Whether the series Files tab lists any file for this version.
    public static func hasFiles(_ detail: ItemDetail, editionId: Int) -> Bool {
        guard detail.isSeries else { return true }
        return detail.allEpisodes.contains { $0.file(for: editionId) != nil }
    }

    /// The queue rows for one version that are still live (not completed / failed).
    public static func liveRows(_ queue: [QueueItem], itemId: Int, editionId: Int) -> [QueueItem] {
        queue.filter {
            let s = $0.status.lowercased()
            return $0.mediaItemId == itemId && $0.editionId == editionId && s != "completed" && s != "failed"
        }
    }

    /// The live rows' mean progress (0–100), nil when there are none.
    public static func progress(_ rows: [QueueItem]) -> Double? {
        guard !rows.isEmpty else { return nil }
        return rows.map(\.progress).reduce(0, +) / Double(rows.count)
    }

    /// A live row waiting on a manual import (`held`, or flagged as needing you).
    public static func isHeld(_ rows: [QueueItem]) -> Bool {
        rows.contains { $0.status.lowercased() == "held" || $0.needsAttention == true }
    }
}
