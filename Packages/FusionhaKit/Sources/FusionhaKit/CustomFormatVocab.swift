import Foundation

// The custom-format editor's pure rules (web `cf-spec-vocab.ts`,
// `CfConditionBlocks.groupBlocks`, the library rail filters in
// `CustomFormatsPanel.tsx`).

public struct CFSpecOption: Sendable, Hashable {
    public let value: String
    public let label: String
}

public struct CFSpecType: Sendable, Hashable {
    public let value: String
    public let label: String
    /// The small glyph the block headers and the type menu use.
    public let icon: String
}

public enum CFSpecVocab {
    /// The eight specification types the scoring engine supports.
    public static let types: [CFSpecType] = [
        CFSpecType(value: "release_title", label: "Release Title", icon: "“”"),
        CFSpecType(value: "release_group", label: "Release Group", icon: "⦿"),
        CFSpecType(value: "source", label: "Source", icon: "▤"),
        CFSpecType(value: "resolution", label: "Resolution", icon: "▦"),
        CFSpecType(value: "language", label: "Language", icon: "Aa"),
        CFSpecType(value: "quality_modifier", label: "Quality Modifier", icon: "✦"),
        CFSpecType(value: "indexer_flag", label: "Indexer Flag", icon: "⚑"),
        CFSpecType(value: "release_type", label: "Release Type", icon: "▶"),
    ]

    private static func opts(_ pairs: [(String, String)]) -> [CFSpecOption] {
        pairs.map { CFSpecOption(value: $0.0, label: $0.1) }
    }

    /// Fixed-vocabulary types; anything absent (release title / group) is a regex.
    private static let vocab: [String: [CFSpecOption]] = [
        "source": opts([("BLURAY", "BluRay"), ("WEBDL", "WEB-DL"), ("WEBRIP", "WEBRip"), ("HDTV", "HDTV"), ("DVD", "DVD")]),
        "resolution": opts([("2160", "2160p (4K)"), ("1080", "1080p"), ("720", "720p"), ("480", "480p")]),
        "language": opts([("English", "English"), ("Japanese", "Japanese"), ("Multi", "Multi"),
                          ("Dual Audio", "Dual Audio"), ("German", "German"), ("French", "French"),
                          ("Italian", "Italian"), ("Original", "Original")]),
        "quality_modifier": opts([("none", "None"), ("remux", "Remux"), ("rawhd", "Raw-HD"), ("brdisk", "BR-DISK")]),
        "indexer_flag": opts([("freeleech", "Freeleech"), ("halfleech", "Halfleech"), ("doubleUpload", "Double Upload"),
                              ("internal", "Internal"), ("scene", "Scene"), ("nuked", "Nuked")]),
        "release_type": opts([("singleEpisode", "Single Episode"), ("multiEpisode", "Multi Episode"),
                              ("seasonPack", "Season Pack")]),
    ]

    /// The enum options for a type, or nil when it takes a free-text regex.
    public static func options(for type: String) -> [CFSpecOption]? { vocab[type] }

    public static func label(_ type: String) -> String { types.first { $0.value == type }?.label ?? type }
    public static func icon(_ type: String) -> String { types.first { $0.value == type }?.icon ?? "·" }

    /// The display label of a value (an unknown stored value shows as-is).
    public static func valueLabel(_ type: String, _ value: String) -> String {
        options(for: type)?.first { $0.value == value }?.label ?? value
    }

    /// A fresh condition's value: the first enum option, empty for a regex type.
    public static func defaultValue(_ type: String) -> String { options(for: type)?.first?.value ?? "" }

    /// A fresh condition: unstarred (optional, an OR member of its block).
    public static func newSpec(_ type: String) -> CustomFormatSpec {
        CustomFormatSpec(specType: type, value: defaultValue(type), negate: false, required: false)
    }
}

/// One visual block: a spec type and the indices of its conditions in the
/// flat list (first-appearance order, so saves keep a stable order).
public struct CFBlock: Sendable, Hashable {
    public let type: String
    public let indices: [Int]
}

public enum CFBlocks {
    public static func group(_ specs: [CustomFormatSpec]) -> [CFBlock] {
        var order: [String] = []
        var byType: [String: [Int]] = [:]
        for (i, spec) in specs.enumerated() {
            if byType[spec.specType] == nil { order.append(spec.specType) }
            byType[spec.specType, default: []].append(i)
        }
        return order.map { CFBlock(type: $0, indices: byType[$0] ?? []) }
    }

    /// Inserts a sibling right after the block's last condition so blocks stay contiguous.
    public static func addToBlock(_ specs: [CustomFormatSpec], _ block: CFBlock) -> [CustomFormatSpec] {
        var next = specs
        let after = (block.indices.last ?? (specs.count - 1)) + 1
        next.insert(CFSpecVocab.newSpec(block.type), at: min(after, next.count))
        return next
    }
}

/// The library rail: provenance chips, kind chips, search, "used in N".
public enum CFLibrary {
    public static let chipLabels: [(String, String)] = [
        ("all", "All"), ("trash", "TRaSH"), ("arr", "arr"), ("preset", "Preset"), ("manual", "Manual"),
    ]
    public static let kinds: [(String, String)] = [("movie", "Movie"), ("series", "Series"), ("anime", "Anime")]

    /// `MV` / `SR` / `AN` (nil for a legacy no-kind row).
    public static func kindTag(_ kind: String?) -> String? {
        switch kind {
        case "movie": return "MV"
        case "series": return "SR"
        case "anime": return "AN"
        default: return nil
        }
    }

    public static func isKind(_ kind: String?) -> Bool { kindTag(kind) != nil }

    /// "All" plus every provenance present, in the web's order.
    public static func chips(_ formats: [CustomFormatInfo]) -> [String] {
        let present = Set(formats.map(\.provenance))
        return ["all"] + chipLabels.map { $0.0 }.filter { $0 != "all" && present.contains($0) }
    }

    public static func filter(_ formats: [CustomFormatInfo], query: String, chip: String, kind: String) -> [CustomFormatInfo] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return formats.filter { f in
            if chip != "all" && f.provenance != chip { return false }
            if kind != "all" && f.mediaKind != kind { return false }
            if !q.isEmpty && !f.name.lowercased().contains(q) { return false }
            return true
        }
    }

    /// How many profiles carry a non-zero score for this format.
    public static func usedIn(_ profiles: [ProfileScoringSummary], formatId: Int) -> Int {
        profiles.filter { p in (p.formatScores ?? []).contains { $0.customFormatId == formatId && ($0.score ?? 0) != 0 } }.count
    }

    /// `formatScore`: `+5`, `−10` (a real minus sign).
    public static func score(_ n: Int) -> String { n < 0 ? "−\(abs(n))" : "+\(n)" }

    /// "3 specs" / "1 spec".
    public static func specCount(_ n: Int) -> String { "\(n) spec" + (n == 1 ? "" : "s") }
}
