import Foundation

/// Settings › Connections "+ Add connection" rules (web `InstancesPanel.tsx`
/// `AddConnectionDialog`): the auto-derived slug, the series-only scope and
/// the anime-scoped identity suggestion.
public enum ConnectionCreate {
    public static let scopes: [(value: String, label: String)] = [
        ("all", "All series"), ("anime", "Anime only"), ("non_anime", "Non-anime"),
    ]

    /// lowercase-kebab-case of a display name.
    public static func slugify(_ name: String) -> String {
        var out = ""
        var pendingDash = false
        for scalar in name.lowercased().trimmingCharacters(in: .whitespaces).unicodeScalars {
            let ascii = scalar.isASCII && (CharacterSet.lowercaseLetters.contains(scalar)
                || CharacterSet.decimalDigits.contains(scalar))
            if ascii {
                if pendingDash && !out.isEmpty { out.append("-") }
                pendingDash = false
                out.unicodeScalars.append(scalar)
            } else {
                pendingDash = true
            }
        }
        return out
    }

    /// The backend only takes a non-`all` scope on a series connection.
    public static func scopeApplies(kind: String) -> Bool { kind == "series" }

    /// `Sonarr-Anime-4K` / `sonarr-anime-4k` for an anime-only Sonarr.
    public static func animeSuggestion(tier: QualityTier) -> (name: String, slug: String) {
        let suffix = tier == .uhd ? "4K" : "HD"
        return ("Sonarr-Anime-\(suffix)", "sonarr-anime-\(suffix.lowercased())")
    }

    /// The `InstanceCreate` body. `limits` are the offer-only fields (nulls
    /// for "Everything").
    public static func body(name: String, slug: String, flavor: String, kind: String, tier: QualityTier,
                            scope: String, limits: [String: SettingsJSON]) -> SettingsJSON {
        var fields: [String: SettingsJSON] = [
            "slug": .string(slug.trimmingCharacters(in: .whitespaces)),
            "flavor": .string(flavor),
            "kind": .string(kind),
            "tier": .string(tier.rawValue),
            "instance_name": .string(name.trimmingCharacters(in: .whitespaces)),
            "enabled": .bool(true),
            "scope": .string(scopeApplies(kind: kind) ? scope : "all"),
        ]
        for (key, value) in limits { fields[key] = value }
        return .object(fields)
    }
}
