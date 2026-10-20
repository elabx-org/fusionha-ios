import SwiftUI
import FusionhaKit

// `makeDefaults` heuristics: the default root folder and profile per tier.
extension AddFlow {
    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func defaultRootId(_ tier: QualityTier, kind: MediaKind, roots: [RootFolder]) -> Int {
        let wants4k = tier == .uhd
        let kindMatch = { (r: RootFolder) in
            kind == .series ? matches(r.path, "tv|anime|series|show") : matches(r.path, "movie|film")
        }
        let tierMatch = { (r: RootFolder) in matches(r.path, "4k|2160|uhd") == wants4k }
        let chosen = roots.first { kindMatch($0) && tierMatch($0) } ?? roots.first(where: kindMatch)
            ?? roots.first(where: tierMatch) ?? roots.first
        return chosen?.id ?? 0
    }

    static func defaultProfileId(_ tier: QualityTier, resolvedKind: String, profiles: [QualityProfileSummary]) -> Int {
        let wants4k = tier == .uhd
        let is4k = { (p: QualityProfileSummary) in
            matches(p.name, "4k|2160|uhd|ultra") || (p.allowedQualities ?? []).contains { matches($0, "2160|4k|uhd") }
        }
        let anime = resolvedKind == "anime" ? profiles.first { $0.mediaKind == "anime" && is4k($0) == wants4k } : nil
        let chosen = anime ?? profiles.first { is4k($0) == wants4k } ?? profiles.first
        return chosen?.id ?? 0
    }
}
