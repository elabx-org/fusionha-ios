import Foundation

// v2 Manage episodes, Files tab (owner-approved mock, 2026-11-06): the
// title's files grouped one card per season, the season's shared facts said
// once in its header and only the differences on a row, tri-state season
// selection, quick "select by" rules and the bulk bar's totals. Pure: the
// sheet owns the selection set, this says what it means.

/// One fact chip (source + resolution, audio, release group).
public struct ManageFact: Sendable, Hashable, Identifiable {
    public enum Kind: Int, Sendable, CaseIterable {
        case source, audio, group

        public var spoken: String {
            switch self {
            case .source: return "quality"
            case .audio: return "audio"
            case .group: return "group"
            }
        }
    }

    public let kind: Kind
    public let text: String
    /// Not the value the rest of the season shares (drawn in orange).
    public let differs: Bool
    public var id: Kind { kind }

    public init(kind: Kind, text: String, differs: Bool = false) {
        self.kind = kind
        self.text = text
        self.differs = differs
    }
}

/// One file's row in its season card.
public struct ManageEpisodeLine: Sendable, Hashable, Identifiable {
    public let item: ManagedFileItem
    /// `S01·E01` (or `S01·E01–E03`), `S01` for a file with no episode.
    public let code: String
    public let title: String?
    /// Minutes: the probed runtime, else the provider's.
    public let minutes: Int?
    /// Only the facts that are not the season's shared value.
    public let chips: [ManageFact]
    public var id: Int { item.id }
    public var bytes: Double { item.row.size.isFinite && item.row.size > 0 ? item.row.size : 0 }
}

/// One season's card.
public struct ManageSeasonGroup: Sendable, Hashable, Identifiable {
    /// `-1` for files the server has no season for.
    public let season: Int
    public let lines: [ManageEpisodeLine]
    /// Facts every (or most) of the season's files share, in order.
    public let shared: [ManageFact]
    /// The versions the season's files belong to, in tier order.
    public let tiers: [QualityTier]
    public var id: Int { season }

    public var title: String {
        switch season {
        case -1: return "Other files"
        case 0: return "Specials"
        default: return "Season \(season)"
        }
    }

    /// The quick chip's label: `S1`, `SP` for specials.
    public var shortTitle: String { season == 0 ? "SP" : season < 0 ? "Other" : "S\(season)" }
    public var fileIds: Set<Int> { Set(lines.map(\.id)) }
    public var bytes: Double { lines.reduce(0) { $0 + $1.bytes } }
    public var count: Int { lines.count }
}

public enum ManageSelectState: Sendable, Equatable {
    case none, partial, all
}

/// What the bulk bar and the delete confirmation say about a selection.
public struct ManageSelectionSummary: Sendable, Equatable {
    public let count: Int
    public let bytes: Double
    /// The seasons any selected file sits in, ascending.
    public let seasons: [Int]

    /// `Season 1`, `Seasons 1 and 4`, `3 seasons`, `Specials`.
    public var seasonsText: String { ManageEpisodes.seasonsText(seasons) }
    public var size: String { DetailText.bytes(bytes) }
}

public enum ManageEpisodes {
    // MARK: Grouping

    /// One group per season, ascending (unknown season last), rows in
    /// episode order. `detail` supplies titles, runtimes and probed audio.
    public static func groups(_ items: [ManagedFileItem], detail: ItemDetail) -> [ManageSeasonGroup] {
        let lookup = Lookup(detail)
        let bySeason = Dictionary(grouping: items) { $0.row.season ?? -1 }
        let order = bySeason.keys.sorted { a, b in a < 0 ? false : b < 0 ? true : a < b }
        return order.map { season in
            let files = (bySeason[season] ?? []).sorted { a, b in
                (a.row.episodes.min() ?? .max, a.id) < (b.row.episodes.min() ?? .max, b.id)
            }
            let values = files.map { file in ManageFact.Kind.allCases.map { value($0, of: file, lookup: lookup) } }
            let shared: [ManageFact] = ManageFact.Kind.allCases.compactMap { kind in
                sharedValue(values.map { $0[kind.rawValue] }).map { ManageFact(kind: kind, text: $0) }
            }
            let common = Dictionary(shared.map { ($0.kind, $0.text) }, uniquingKeysWith: { a, _ in a })
            let lines = zip(files, values).map { file, facts in
                ManageEpisodeLine(item: file, code: code(file),
                                  title: lookup.episode(file)?.title,
                                  minutes: minutes(file, lookup: lookup),
                                  chips: ManageFact.Kind.allCases.compactMap { kind in
                                      guard let text = facts[kind.rawValue], common[kind] != text else { return nil }
                                      return ManageFact(kind: kind, text: text, differs: common[kind] != nil)
                                  })
            }
            let tierSet = Set(files.map(\.row.tier))
            let tiers = detail.orderedEditions.map(\.tier).filter { tierSet.contains($0) }.uniqued()
            return ManageSeasonGroup(season: season, lines: lines, shared: shared,
                                     tiers: tiers.isEmpty ? Array(tierSet) : tiers)
        }
    }

    /// The value most files that have one agree on: at least two files, and
    /// more than half of those with a value (the season page's rule).
    public static func sharedValue(_ values: [String?]) -> String? {
        let known = values.compactMap { $0 }
        guard known.count >= 2 else { return nil }
        var counts: [String: Int] = [:]
        for v in known { counts[v, default: 0] += 1 }
        guard let top = counts.max(by: { ($0.value, $1.key) < ($1.value, $0.key) }), top.value * 2 > known.count else { return nil }
        return top.key
    }

    // MARK: Selection

    public static func state(_ group: ManageSeasonGroup, selected: Set<Int>) -> ManageSelectState {
        let n = group.fileIds.intersection(selected).count
        return n == 0 ? .none : n == group.count ? .all : .partial
    }

    /// The season's circle: all selected → none of it; otherwise all of it.
    public static func toggling(_ group: ManageSeasonGroup, in selected: Set<Int>) -> Set<Int> {
        state(group, selected: selected) == .all ? selected.subtracting(group.fileIds) : selected.union(group.fileIds)
    }

    public static func summary(_ selected: Set<Int>, groups: [ManageSeasonGroup]) -> ManageSelectionSummary {
        var count = 0, bytes = 0.0, seasons: [Int] = []
        for g in groups {
            let picked = g.lines.filter { selected.contains($0.id) }
            guard !picked.isEmpty else { continue }
            count += picked.count
            bytes += picked.reduce(0) { $0 + $1.bytes }
            seasons.append(g.season)
        }
        return ManageSelectionSummary(count: count, bytes: bytes, seasons: seasons)
    }

    public static func seasonsText(_ seasons: [Int]) -> String {
        func name(_ s: Int) -> String { s == 0 ? "Specials" : s < 0 ? "other files" : "Season \(s)" }
        switch seasons.count {
        case 0: return ""
        case 1: return name(seasons[0]).capitalizedFirst
        case 2:
            if seasons.allSatisfy({ $0 > 0 }) { return "Seasons \(seasons[0]) and \(seasons[1])" }
            return "\(name(seasons[0])) and \(name(seasons[1]))".capitalizedFirst
        default: return "\(seasons.count) seasons"
        }
    }

    // MARK: Select by

    /// The release groups on disk, most files first.
    public static func releaseGroups(_ groups: [ManageSeasonGroup]) -> [String] {
        ranked(groups.flatMap(\.lines).compactMap { group($0.item) })
    }

    /// The qualities on disk as raw codes, most files first.
    public static func qualities(_ groups: [ManageSeasonGroup]) -> [String] {
        ranked(groups.flatMap(\.lines).map(\.item.row.quality).filter { !$0.isEmpty })
    }

    public static func ids(_ groups: [ManageSeasonGroup], releaseGroup: String) -> Set<Int> {
        Set(groups.flatMap(\.lines).filter { group($0.item) == releaseGroup }.map(\.id))
    }

    public static func ids(_ groups: [ManageSeasonGroup], quality: String) -> Set<Int> {
        Set(groups.flatMap(\.lines).filter { $0.item.row.quality == quality }.map(\.id))
    }

    public static func ids(_ groups: [ManageSeasonGroup], largerThan bytes: Double) -> Set<Int> {
        Set(groups.flatMap(\.lines).filter { $0.bytes > bytes }.map(\.id))
    }

    /// The "Larger than…" steps offered (GB), those that pick something but not everything.
    public static func sizeSteps(_ groups: [ManageSeasonGroup]) -> [Double] {
        let sizes = groups.flatMap(\.lines).map(\.bytes)
        return [1, 2, 3, 4, 5, 8, 10, 15, 20, 30, 50].filter { gb in
            let n = sizes.filter { $0 > gb * gigabyte }.count
            return n > 0 && n < sizes.count
        }
    }

    public static let gigabyte: Double = 1024 * 1024 * 1024

    // MARK: Delete

    /// The episodes the selected files cover (for "Stop monitoring").
    public static func episodeIds(_ items: [ManagedFileItem], detail: ItemDetail) -> [Int] {
        let lookup = Lookup(detail)
        var out: [Int] = []
        var seen = Set<Int>()
        for item in items {
            guard let s = item.row.season else { continue }
            for e in item.row.episodes {
                if let id = lookup.episodes["\(s):\(e)"]?.id, seen.insert(id).inserted { out.append(id) }
            }
        }
        return out
    }

    /// "Seasons 1 and 4 of 13 Reasons Why. This frees 75.4 GB. The files are
    /// removed from disk; the episodes stay in your library."
    public static func deleteMessage(_ summary: ManageSelectionSummary, title: String) -> String {
        let scope = summary.seasonsText.isEmpty ? title : "\(summary.seasonsText) of \(title)"
        return "\(scope). This frees \(summary.size). The files are removed from disk; the episodes stay in your library."
    }

    // MARK: Helpers

    static func code(_ item: ManagedFileItem) -> String {
        if let label = item.episodeLabel { return label }
        return item.row.season.map { EpisodeCode.season($0) } ?? "—"
    }

    static func group(_ item: ManagedFileItem) -> String? {
        guard let g = item.row.releaseGroup?.trimmingCharacters(in: .whitespaces), !g.isEmpty else { return nil }
        return g
    }

    static func value(_ kind: ManageFact.Kind, of item: ManagedFileItem, lookup: Lookup) -> String? {
        switch kind {
        case .source: return FileNameFacts.qualityText(item.row.quality)
        case .audio: return lookup.files[item.id]?.probedAudio
        case .group: return group(item)
        }
    }

    static func minutes(_ item: ManagedFileItem, lookup: Lookup) -> Int? {
        if let s = item.row.runtimeSeconds, s > 0 { return Int((s / 60).rounded()) }
        return lookup.episode(item)?.runtime
    }

    private static func ranked(_ values: [String]) -> [String] {
        var counts: [String: Int] = [:]
        for v in values { counts[v, default: 0] += 1 }
        return counts.sorted { ($0.value, $1.key) > ($1.value, $0.key) }.map(\.key)
    }

    struct Lookup {
        var episodes: [String: Episode] = [:]
        var files: [Int: MovieFile] = [:]

        init(_ detail: ItemDetail) {
            for s in detail.seasons ?? [] {
                for e in s.episodes {
                    episodes["\(s.seasonNumber):\(e.episodeNumber)"] = e
                    for f in e.files ?? [] { if let file = f.file { files[file.id] = file } }
                }
            }
        }

        func episode(_ item: ManagedFileItem) -> Episode? {
            guard let s = item.row.season, let first = item.row.episodes.min() else { return nil }
            return episodes["\(s):\(first)"]
        }
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
