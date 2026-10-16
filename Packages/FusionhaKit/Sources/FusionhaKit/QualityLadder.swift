import Foundation

// The quality-profile editor's ladder model, ported from the web's
// components/settings/quality-groups.ts. A profile's ranked list is an ordered
// array of rows, best-first (top = highest rank). A row is a standalone quality
// or a named group whose members rank equal (arr parity). Quality names are the
// backend `QualityName` strings (`BLURAY_1080P` …).

public struct QualityLadderQuality: Hashable, Sendable {
    public var quality: String
    public var allowed: Bool
    public init(quality: String, allowed: Bool) {
        self.quality = quality
        self.allowed = allowed
    }
}

public struct QualityLadderGroup: Hashable, Sendable {
    /// A local id (never sent): the row key and the cutoff's reference.
    public var id: String
    public var name: String
    public var allowed: Bool
    /// Members in their stored (wire) order. They rank equal, so this is not a ranking.
    public var qualities: [String]
    public init(id: String, name: String, allowed: Bool, qualities: [String]) {
        self.id = id
        self.name = name
        self.allowed = allowed
        self.qualities = qualities
    }
}

public enum QualityLadderRow: Hashable, Sendable, Identifiable {
    case quality(QualityLadderQuality)
    case group(QualityLadderGroup)

    public var id: String {
        switch self {
        case .quality(let q): return "q:\(q.quality)"
        case .group(let g): return "g:\(g.id)"
        }
    }

    public var group: QualityLadderGroup? {
        if case .group(let g) = self { return g }
        return nil
    }

    public var allowed: Bool {
        switch self {
        case .quality(let q): return q.allowed
        case .group(let g): return g.allowed
        }
    }
}

/// What the upgrade cutoff points at. A group selection may carry the cutoff
/// quality the profile was seeded with, so a no-op save writes back the same member.
public enum QualityCutoffSelection: Hashable, Sendable {
    case quality(String)
    case group(id: String, quality: String?)

    /// The Upgrade Until picker's tag: `q:<QUALITY>` or `g:<id>`.
    public var tag: String {
        switch self {
        case .quality(let q): return "q:\(q)"
        case .group(let id, _): return "g:\(id)"
        }
    }

    public static func fromTag(_ tag: String) -> QualityCutoffSelection {
        tag.hasPrefix("g:") ? .group(id: String(tag.dropFirst(2)), quality: nil) : .quality(String(tag.dropFirst(2)))
    }
}

public struct QualityLadderModel: Hashable, Sendable {
    public var rows: [QualityLadderRow]
    public var cutoff: QualityCutoffSelection
    public init(rows: [QualityLadderRow], cutoff: QualityCutoffSelection) {
        self.rows = rows
        self.cutoff = cutoff
    }
}

/// `cutoff` + `cutoff_group` + `cutoff_group_index`, as the backend stores them.
public struct QualityResolvedCutoff: Hashable, Sendable {
    public let cutoff: String
    public let cutoffGroup: String?
    public let cutoffGroupIndex: Int?
}

public enum QualityLadder {
    /// Editor display order, best → worst (`quality-names.ts`). `UNKNOWN` is never a tier.
    public static let order: [String] = [
        "REMUX_2160P", "BLURAY_2160P", "WEBDL_2160P", "WEBRIP_2160P", "HDTV_2160P",
        "REMUX_1080P", "BLURAY_1080P", "WEBDL_1080P", "WEBRIP_1080P", "RAWHD", "HDTV_1080P",
        "BLURAY_720P", "WEBDL_720P", "WEBRIP_720P", "HDTV_720P",
        "BLURAY_576P", "BLURAY_480P", "DVD", "DVDR", "WEBDL_480P", "WEBRIP_480P", "SDTV",
        "BRDISK", "DVDSCR", "REGIONAL", "TELECINE", "TELESYNC", "CAM", "WORKPRINT",
    ]

    public static func label(_ quality: String) -> String { DetailText.quality(quality) }

    static func orderIndex(_ q: String) -> Int { order.firstIndex(of: q) ?? order.count }

    public static func newGroupId() -> String { "grp-\(UUID().uuidString)" }

    /// Next default group name ("Quality Group N"), unique against `rows`.
    public static func nextGroupName(_ rows: [QualityLadderRow]) -> String {
        let groups = rows.compactMap(\.group)
        let taken = Set(groups.map(\.name))
        var n = groups.count + 1
        while taken.contains("Quality Group \(n)") { n += 1 }
        return "Quality Group \(n)"
    }

    private static let webPairs: [(res: String, webdl: String, webrip: String)] = [
        ("2160p", "WEBDL_2160P", "WEBRIP_2160P"), ("1080p", "WEBDL_1080P", "WEBRIP_1080P"),
        ("720p", "WEBDL_720P", "WEBRIP_720P"), ("480p", "WEBDL_480P", "WEBRIP_480P"),
    ]
    private static let defaultAllowed: Set<String> = [
        "BLURAY_1080P", "WEBDL_1080P", "WEBRIP_1080P", "HDTV_1080P",
        "BLURAY_720P", "WEBDL_720P", "WEBRIP_720P", "HDTV_720P",
    ]
    private static let defaultCutoff = "BLURAY_1080P"

    /// A brand-new profile: the full ladder with the four `WEB {res}` groups, the
    /// HD-1080p allowed set and the Bluray-1080p cutoff.
    public static func defaultModel() -> QualityLadderModel {
        let absorbed = Set(webPairs.map(\.webrip))
        var rows: [QualityLadderRow] = []
        for q in order where !absorbed.contains(q) {
            if let pair = webPairs.first(where: { $0.webdl == q }) {
                rows.append(.group(QualityLadderGroup(id: newGroupId(), name: "WEB \(pair.res)",
                                                      allowed: defaultAllowed.contains(pair.webdl),
                                                      qualities: [pair.webdl, pair.webrip])))
            } else {
                rows.append(.quality(QualityLadderQuality(quality: q, allowed: defaultAllowed.contains(q))))
            }
        }
        return QualityLadderModel(rows: rows, cutoff: .quality(defaultCutoff))
    }

    /// Seed the editor from a saved profile. `items` (worst-first on the wire) is
    /// authoritative; otherwise the flat `allowed_qualities`. Every tier appears once.
    public static func seed(_ profile: QualityProfileRecord) -> QualityLadderModel {
        guard let items = profile.items, !items.isEmpty else {
            let allowed = Set(profile.allowedQualities)
            let rows = order.map { QualityLadderRow.quality(QualityLadderQuality(quality: $0, allowed: allowed.contains($0))) }
            return QualityLadderModel(rows: rows, cutoff: .quality(profile.cutoff))
        }
        let sorted = items.enumerated().sorted {
            $0.element.order != $1.element.order ? $0.element.order > $1.element.order : $0.offset < $1.offset
        }
        var rows: [QualityLadderRow] = []
        var used = Set<String>()
        var groups: [(index: Int, group: QualityLadderGroup)] = []
        for (index, item) in sorted {
            switch item {
            case .group(let name, let allowed, _, let qualities):
                let members = qualities.filter { !used.contains($0) }
                used.formUnion(members)
                let g = QualityLadderGroup(id: newGroupId(), name: name, allowed: allowed, qualities: members)
                rows.append(.group(g))
                groups.append((index, g))
            case .quality(let quality, let allowed, _):
                guard !used.contains(quality) else { continue }
                used.insert(quality)
                rows.append(.quality(QualityLadderQuality(quality: quality, allowed: allowed)))
            }
        }
        for q in order where !used.contains(q) {
            rows.append(.quality(QualityLadderQuality(quality: q, allowed: false)))
        }
        return QualityLadderModel(rows: rows, cutoff: seedCutoff(profile, groups))
    }

    private static func seedCutoff(_ profile: QualityProfileRecord,
                                   _ groups: [(index: Int, group: QualityLadderGroup)]) -> QualityCutoffSelection {
        func pick(_ g: QualityLadderGroup) -> QualityCutoffSelection {
            .group(id: g.id, quality: g.qualities.contains(profile.cutoff) ? profile.cutoff : nil)
        }
        if let index = profile.cutoffGroupIndex, let hit = groups.first(where: { $0.index == index }) {
            return pick(hit.group)
        }
        guard let name = profile.cutoffGroup, !name.isEmpty else { return .quality(profile.cutoff) }
        let namesakes = groups.map(\.group).filter { $0.name == name }
        guard let owner = namesakes.first(where: { $0.qualities.contains(profile.cutoff) }) ?? namesakes.first else {
            return .quality(profile.cutoff)
        }
        return pick(owner)
    }

    public static func isAllowed(_ rows: [QualityLadderRow], _ quality: String) -> Bool {
        for r in rows {
            switch r {
            case .quality(let q) where q.quality == quality: return q.allowed
            case .group(let g) where g.qualities.contains(quality): return g.allowed
            default: continue
            }
        }
        return false
    }

    public static func groupOf(_ rows: [QualityLadderRow], _ quality: String) -> QualityLadderGroup? {
        rows.compactMap(\.group).first { $0.qualities.contains(quality) }
    }

    /// Best-first flat list of every effectively-allowed quality (editor direction).
    public static func flatAllowed(_ rows: [QualityLadderRow]) -> [String] {
        rows.flatMap { r -> [String] in
            switch r {
            case .quality(let q): return q.allowed ? [q.quality] : []
            case .group(let g): return g.allowed ? g.qualities : []
            }
        }
    }

    /// The `allowed_qualities` wire order: worst-first; a group's members keep their stored order.
    public static func allowedPayload(_ rows: [QualityLadderRow]) -> [String] {
        rows.reversed().flatMap { r -> [String] in
            switch r {
            case .quality(let q): return q.allowed ? [q.quality] : []
            case .group(let g): return g.allowed ? g.qualities : []
            }
        }
    }

    /// Rows `items` actually emits (empty groups dropped).
    static func visibleRows(_ rows: [QualityLadderRow]) -> [QualityLadderRow] {
        rows.filter { $0.group.map { !$0.qualities.isEmpty } ?? true }
    }

    /// The grouped `items` payload: top row gets the highest `order`, numbered from 0.
    public static func items(_ rows: [QualityLadderRow]) -> [SettingsJSON] {
        let visible = visibleRows(rows)
        return visible.enumerated().map { (idx, r) -> SettingsJSON in
            let order = visible.count - 1 - idx
            switch r {
            case .group(let g):
                return ["type": "group", "name": .string(g.name), "allowed": .bool(g.allowed),
                        "order": .int(order), "qualities": .array(g.qualities.map(SettingsJSON.string))]
            case .quality(let q):
                return ["type": "quality", "quality": .string(q.quality), "allowed": .bool(q.allowed), "order": .int(order)]
            }
        }
    }

    /// Resolve the selection into what the backend stores, snapping a stale one
    /// to the best allowed quality (and its group).
    public static func resolveCutoff(_ rows: [QualityLadderRow], _ cutoff: QualityCutoffSelection) -> QualityResolvedCutoff {
        let allowed = flatAllowed(rows)
        let visible = visibleRows(rows)
        func grouped(_ g: QualityLadderGroup, _ q: String) -> QualityResolvedCutoff {
            QualityResolvedCutoff(cutoff: q, cutoffGroup: g.name,
                                  cutoffGroupIndex: visible.firstIndex(of: .group(g)))
        }
        switch cutoff {
        case .group(let id, let carried):
            if let g = rows.compactMap(\.group).first(where: { $0.id == id }), !g.qualities.isEmpty {
                if let carried, g.qualities.contains(carried) { return grouped(g, carried) }
                let best = g.qualities.min { orderIndex($0) < orderIndex($1) } ?? g.qualities[0]
                return grouped(g, best)
            }
        case .quality(let q):
            if allowed.contains(q) {
                if let g = groupOf(rows, q) { return grouped(g, q) }
                return QualityResolvedCutoff(cutoff: q, cutoffGroup: nil, cutoffGroupIndex: nil)
            }
        }
        let fallback = allowed.first ?? order[order.count - 1]
        if let g = groupOf(rows, fallback) { return grouped(g, fallback) }
        return QualityResolvedCutoff(cutoff: fallback, cutoffGroup: nil, cutoffGroupIndex: nil)
    }

    /// The editor's cutoff-keeper: a vanished group or disallowed quality snaps to
    /// the best allowed quality (its group when it has one).
    public static func repairedCutoff(_ model: QualityLadderModel) -> QualityCutoffSelection {
        let allowed = flatAllowed(model.rows)
        let stale: Bool
        switch model.cutoff {
        case .group(let id, _): stale = !model.rows.contains { $0.group?.id == id }
        case .quality(let q): stale = !allowed.contains(q)
        }
        guard stale, let best = allowed.first else { return model.cutoff }
        if let g = groupOf(model.rows, best) { return .group(id: g.id, quality: nil) }
        return .quality(best)
    }

    /// The Upgrade Until options: allowed groups + allowed standalone qualities, best-first.
    public static func cutoffOptions(_ rows: [QualityLadderRow]) -> [(tag: String, label: String)] {
        rows.compactMap { r -> (tag: String, label: String)? in
            switch r {
            case .group(let g):
                return g.allowed && !g.qualities.isEmpty ? ("g:\(g.id)", g.name.isEmpty ? "Quality group" : g.name) : nil
            case .quality(let q):
                return q.allowed ? ("q:\(q.quality)", label(q.quality)) : nil
            }
        }
    }

    public static func cutoffLabel(_ model: QualityLadderModel) -> String {
        switch model.cutoff {
        case .group(let id, _): return model.rows.compactMap(\.group).first { $0.id == id }?.name ?? "Quality group"
        case .quality(let q): return label(q)
        }
    }
}
