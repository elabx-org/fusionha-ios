import Foundation

// The quality-profile save body, built exactly as the web editor builds it
// (`QualityProfilesPanel.tsx` save / duplicateBody): the ladder block, the
// per-format scores with their override flags (#166), and the #165 rule that an
// update omits an untouched ladder. `upgrade_until` is never sent; Upgrade Until
// is the cutoff and the server coerces it.

public struct QualityProfileScoreBaseline: Hashable, Sendable {
    public let score: Int
    public let isOverride: Bool
}

/// The editor's non-ladder fields, as typed.
public struct QualityProfileFields: Hashable, Sendable {
    public var name: String
    public var mediaKind: String?
    public var upgradeAllowed: Bool
    public var minScore: String
    /// Blank = no ceiling.
    public var cutoffFormatScore: String
    public var minIncrement: String
    public var language: String

    public init(name: String, mediaKind: String?, upgradeAllowed: Bool, minScore: String,
                cutoffFormatScore: String, minIncrement: String, language: String) {
        self.name = name
        self.mediaKind = mediaKind
        self.upgradeAllowed = upgradeAllowed
        self.minScore = minScore
        self.cutoffFormatScore = cutoffFormatScore
        self.minIncrement = minIncrement
        self.language = language
    }

    /// A new profile (Movies) or an existing one's stored values.
    public init(_ profile: QualityProfileRecord?) {
        self.init(name: profile?.name ?? "",
                  mediaKind: profile == nil ? "movie" : profile?.mediaKind,
                  upgradeAllowed: profile?.upgradeAllowed ?? true,
                  minScore: String(profile?.minFormatScore ?? 0),
                  cutoffFormatScore: profile?.cutoffFormatScore.map { String($0) } ?? "",
                  minIncrement: String(profile?.minUpgradeFormatScore ?? 1),
                  language: profile?.language ?? "original")
    }
}

public enum QualityProfileBody {
    /// JS `Number(text) || 0`, as an integer.
    public static func number(_ text: String?) -> Int {
        let t = (text ?? "").trimmingCharacters(in: .whitespaces)
        if let i = Int(t) { return i }
        if let d = Double(t), d.isFinite, abs(d) < 1e15 { return Int(d) }
        return 0
    }

    /// The score stepper's adaptive step (~5% of the magnitude, min 1).
    public static func step(_ score: Int) -> Int {
        max(1, Int((Double(abs(score)) / 20).rounded()))
    }

    /// `cutoff` + `cutoff_group` + `cutoff_group_index` + `allowed_qualities` + `items`.
    public static func ladderBlock(_ model: QualityLadderModel) -> [String: SettingsJSON] {
        let r = QualityLadder.resolveCutoff(model.rows, model.cutoff)
        return [
            "cutoff": .string(r.cutoff),
            "cutoff_group": .optional(r.cutoffGroup),
            "cutoff_group_index": .optional(r.cutoffGroupIndex),
            "allowed_qualities": .array(QualityLadder.allowedPayload(model.rows).map(SettingsJSON.string)),
            "items": .array(QualityLadder.items(model.rows)),
        ]
    }

    public static func baseline(_ profile: QualityProfileRecord?) -> [Int: QualityProfileScoreBaseline] {
        var map: [Int: QualityProfileScoreBaseline] = [:]
        for s in profile?.formatScores ?? [] {
            map[s.customFormatId] = QualityProfileScoreBaseline(score: s.score, isOverride: s.isOverride ?? false)
        }
        return map
    }

    /// Released → false; changed or new → true; untouched → the stored flag.
    public static func isOverride(_ id: Int, live: Int, baseline: [Int: QualityProfileScoreBaseline],
                                  released: Set<Int>) -> Bool {
        if released.contains(id) { return false }
        if live != (baseline[id]?.score ?? 0) { return true }
        return baseline[id]?.isOverride ?? false
    }

    /// Scored rows plus deliberate zero overrides, sorted by format id. The
    /// editor's score map is the source of truth (a failed format fetch can't wipe scores).
    public static func formatScores(scores: [Int: String], formatIDs: [Int],
                                    baseline: [Int: QualityProfileScoreBaseline], released: Set<Int>) -> [SettingsJSON] {
        let ids = Set(scores.keys).union(formatIDs)
        return ids.sorted().compactMap { id -> SettingsJSON? in
            let live = number(scores[id])
            let owned = isOverride(id, live: live, baseline: baseline, released: released)
            guard live != 0 || owned else { return nil }
            let row: SettingsJSON = ["custom_format_id": .int(id), "score": .int(live), "is_override": .bool(owned)]
            return row
        }
    }

    /// The header's "Scored formats" count.
    public static func scoredCount(scores: [Int: String], formatIDs: [Int]) -> Int {
        Set(scores.keys).union(formatIDs).filter { number(scores[$0]) != 0 }.count
    }

    /// The fields every save carries.
    public static func common(_ f: QualityProfileFields, formatScores: [SettingsJSON]) -> [String: SettingsJSON] {
        let ceiling = f.cutoffFormatScore.trimmingCharacters(in: .whitespaces)
        return [
            "name": .string(f.name.trimmingCharacters(in: .whitespaces)),
            "media_kind": .optional(f.mediaKind),
            "upgrade_allowed": .bool(f.upgradeAllowed),
            "min_format_score": .int(number(f.minScore)),
            "cutoff_format_score": ceiling.isEmpty ? .null : .int(number(ceiling)),
            "min_upgrade_format_score": .int(number(f.minIncrement)),
            "language": .string(f.language),
            "format_scores": .array(formatScores),
        ]
    }

    /// The POST / PUT body. On an update whose ladder block equals the one the
    /// untouched profile computes, the ladder (and the cutoff trio) is omitted.
    public static func save(fields: [String: SettingsJSON], model: QualityLadderModel,
                            original: QualityProfileRecord?) -> [String: SettingsJSON] {
        let block = ladderBlock(model)
        if let original, block == ladderBlock(QualityLadder.seed(original)) { return fields }
        return fields.merging(block) { _, new in new }
    }

    /// The card's duplicate: a faithful clone named "<name> (copy)".
    public static func duplicate(_ profile: QualityProfileRecord) -> [String: SettingsJSON] {
        let scores: [SettingsJSON] = profile.formatScores.map { s -> SettingsJSON in
            ["custom_format_id": .int(s.customFormatId), "score": .int(s.score), "is_override": .bool(s.isOverride ?? false)]
        }
        var body: [String: SettingsJSON] = [
            "name": .string("\(profile.name) (copy)"),
            "media_kind": .optional(profile.mediaKind),
            "upgrade_allowed": .bool(profile.upgradeAllowed),
            "min_format_score": .int(profile.minFormatScore),
            "cutoff_format_score": .optional(profile.cutoffFormatScore),
            "min_upgrade_format_score": .int(profile.minUpgradeFormatScore),
            "language": .string(profile.language ?? "original"),
            "format_scores": .array(scores),
        ]
        body.merge(ladderBlock(QualityLadder.seed(profile))) { _, new in new }
        return body
    }
}
