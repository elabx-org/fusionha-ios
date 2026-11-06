import Foundation

/// How v2 groups the Settings panels (mock settings-v2.js `SECTIONS` and
/// `SIDE`). The panels themselves, their slugs, labels and search index are
/// v1's (`SettingsNav`); only the grouping and the extra pages differ.
/// Every v1 panel is in both the home and the sidebar (parity).
enum V2SettingsNav {
    struct Section: Identifiable {
        let id: String
        /// Empty: a gap above the card instead of a header (the mock's).
        let header: String
        let rows: [String]
    }

    /// The Quality and Access group pages (phone home rows that open a list).
    static let groups: [String: [String]] = [
        "group:quality": SettingsNav.groups.first { $0.id == "quality" }?.children ?? [],
        "group:access": SettingsNav.groups.first { $0.id == "access" }?.children ?? [],
    ]

    static let groupTitles = ["group:quality": "Quality", "group:access": "Access"]
    static let groupSubtitles = [
        "group:quality": "Profiles, formats, definitions and more",
        "group:access": "Users, roles, sign-in, Plex, API key",
    ]

    /// Short second lines on the home's lead rows (the mock's `subOf`).
    static let subtitles = [
        "general": "Search, calendar, retention",
        "metadata": "TMDB, TheTVDB and TVmaze",
    ]

    private static func section(_ id: String) -> [String] {
        SettingsNav.sections.first { $0.id == id }?.panels ?? []
    }

    private static func children(_ id: String) -> [String] {
        SettingsNav.groups.first { $0.id == id }?.children ?? []
    }

    /// The phone home: General + Metadata, Media management, the Quality
    /// and Access group rows, Fetching, Requests and System.
    static let home: [Section] = [
        .init(id: "top", header: "", rows: SettingsNav.top),
        .init(id: "media", header: "Media management", rows: children("media")),
        .init(id: "groups", header: "", rows: ["group:quality", "group:access"]),
        .init(id: "fetching", header: "Fetching", rows: section("fetching")),
        .init(id: "requests", header: "Requests", rows: section("requests")),
        .init(id: "system", header: "System", rows: section("system")),
    ]

    /// The open Duo's sidebar: the Overview, then every panel with the
    /// groups spelled out.
    static let sidebar: [Section] = [
        .init(id: "top", header: "", rows: ["overview"] + SettingsNav.top),
        .init(id: "media", header: "Media", rows: children("media")),
        .init(id: "quality", header: "Quality", rows: children("quality")),
        .init(id: "access", header: "Access", rows: children("access")),
        .init(id: "fetching", header: "Fetching", rows: section("fetching")),
        .init(id: "requests", header: "Requests", rows: section("requests")),
        .init(id: "system", header: "System", rows: section("system")),
    ]

    /// A row's label: a panel's, or a group's.
    static func label(_ id: String) -> String {
        if id == "overview" { return "Overview" }
        return groupTitles[id] ?? SettingsNav.panel(id)?.label ?? id
    }

    static func isGroup(_ id: String) -> Bool { groups[id] != nil }

    /// The sidebar row that stands for an open page: nothing open is the
    /// Overview, a group page marks its first panel, a panel marks itself.
    static func sidebarSelection(_ id: String?) -> String? {
        guard let id else { return "overview" }
        return groups[id]?.first ?? SettingsNav.canonical(id)
    }
}
