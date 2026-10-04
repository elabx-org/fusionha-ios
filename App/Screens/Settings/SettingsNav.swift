import Foundation

/// One Settings panel: its slug (`/settings/<id>` on the web), the master-list
/// label, the panel heading + subtitle, and an SF Symbol standing in for the
/// web's stroke icon. Mirrors the web's `settings-nav.tsx`.
struct SettingsPanelInfo: Identifiable, Hashable {
    let id: String
    let label: String
    let title: String
    let subtitle: String
    let icon: String
    /// Import Library: pinned last in its group under a divider, with an ACTION tag.
    var action = false
}

struct SettingsGroupInfo: Identifiable {
    let id: String
    let label: String
    let icon: String
    let children: [String]
}

struct SettingsSectionInfo: Identifiable {
    let id: String
    let label: String
    let panels: [String]
}

enum SettingsNav {
    static let panels: [SettingsPanelInfo] = [
        .init(id: "general", label: "General", title: "General",
              subtitle: "App behaviour and integrations.", icon: "gearshape"),
        .init(id: "metadata", label: "Metadata", title: "Metadata",
              subtitle: "TMDB metadata provider for movies, series & anime.", icon: "book.closed"),
        .init(id: "roots", label: "Root Folders", title: "Root Folders",
              subtitle: "Separate roots per quality tier.", icon: "folder"),
        .init(id: "naming", label: "Naming", title: "Naming",
              subtitle: "File and folder formats, per kind — the preview renders the full path as you type.",
              icon: "pencil.line"),
        .init(id: "filemanagement", label: "File Management", title: "File Management",
              subtitle: "Propers/repacks, recycle bin, extra files, analysis, and the free-space guard.",
              icon: "slider.horizontal.3"),
        .init(id: "import", label: "Import Library", title: "Import Library",
              subtitle: "Scan a root folder and match existing subfolders to TMDB — override any match before importing.",
              icon: "square.and.arrow.down", action: true),
        .init(id: "clients", label: "Download Clients", title: "Download Clients",
              subtitle: "Usenet + torrent, per-client categories.", icon: "arrow.down.to.line"),
        .init(id: "indexers", label: "Indexers", title: "Indexers",
              subtitle: "Torznab / Newznab · synced from Prowlarr.", icon: "magnifyingglass"),
        .init(id: "connect", label: "Connect", title: "Connect",
              subtitle: "Discord / Telegram / webhook notifications for grabs, imports & failures.", icon: "bell"),
        .init(id: "notifications", label: "Notifications", title: "Notifications",
              subtitle: "Native push to your phone & desktop — grabs, imports, failures & requests, per device.",
              icon: "iphone.radiowaves.left.and.right"),
        .init(id: "profiles", label: "Quality Profiles", title: "Quality Profiles",
              subtitle: "Allowed qualities, cutoff, custom-format scoring.", icon: "viewfinder"),
        .init(id: "defaultprofiles", label: "Default Profiles", title: "Default Profiles",
              subtitle: "The quality profile + root folder the Add flow pre-fills per media kind & tier.",
              icon: "tablecells"),
        .init(id: "qualitydefinitions", label: "Quality Definitions", title: "Quality Definitions",
              subtitle: "Per-quality min / preferred / max release size (MB/min).", icon: "ruler"),
        .init(id: "formats", label: "Custom Formats", title: "Custom Formats",
              subtitle: "Specifications that drive grab & upgrade scoring — plus a tester to score release names against a profile.",
              icon: "textformat"),
        .init(id: "releasefilters", label: "Release Filters", title: "Release Filters",
              subtitle: "Reject releases by name before they’re grabbed — Required / Rejected terms (arr Release Profiles).",
              icon: "line.3.horizontal.decrease"),
        .init(id: "editions", label: "Media Versions", title: "Media Versions",
              subtitle: "The cut/variant vocabulary (Director’s Cut · IMAX · Open Matte · Black & White …) for movies and series. Drives parsing and the Add-version presets.",
              icon: "film"),
        .init(id: "trash", label: "TRaSH Guides", title: "TRaSH Guides",
              subtitle: "Import community custom formats + quality profiles; keep them synced.", icon: "trash"),
        .init(id: "instances", label: "Connections", title: "Connections",
              subtitle: "Virtual arr instances Overseerr & Prowlarr connect to, plus your API tokens.",
              icon: "rectangle.split.1x2"),
        .init(id: "appearance", label: "Appearance", title: "Appearance",
              subtitle: "App accent, sign-in screen, and library display — Theme · Login screen · Library display.",
              icon: "paintpalette"),
        .init(id: "security", label: "Security", title: "Security",
              subtitle: "The fusionha app API key for direct /api/v1 access.", icon: "lock"),
        .init(id: "access", label: "Users", title: "Users",
              subtitle: "Login accounts and their access to virtual instances (RBAC).", icon: "person.2"),
        .init(id: "roles", label: "Roles", title: "Roles",
              subtitle: "RBAC roles — bundles of permissions and default capabilities.", icon: "checkmark.shield"),
        .init(id: "signin", label: "Sign-in methods", title: "Sign-in methods",
              subtitle: "Let people sign in with an existing account; new sign-ins are auto-provisioned.", icon: "key"),
        .init(id: "publicaccess", label: "Public access", title: "Public access",
              subtitle: "Anonymous, sign-in-free access to a sample of the app.", icon: "globe"),
        .init(id: "system", label: "System", title: "System Tasks",
              subtitle: "Scheduled background jobs and live command activity.", icon: "clock"),
        .init(id: "database", label: "Database", title: "Database",
              subtitle: "The storage backend — SQLite (default) or Postgres — with an in-app migration.",
              icon: "cylinder.split.1x2"),
        .init(id: "backup", label: "Backup", title: "Backup",
              subtitle: "Scheduled + on-demand database backups — download or delete any snapshot, with automatic retention.",
              icon: "clock.arrow.circlepath"),
        .init(id: "logs", label: "Logs", title: "Logs",
              subtitle: "Live tail of the app log — filter by level or keyword, expand tracebacks, download.",
              icon: "text.alignleft"),
        .init(id: "about", label: "About", title: "About",
              subtitle: "Version, build info, attributions & project links.", icon: "info.circle"),
        .init(id: "experimental", label: "Experimental", title: "Experimental",
              subtitle: "Advanced, opt-in tuning for smarter automatic searches — reversible any time.", icon: "flask"),
        .init(id: "discover", label: "Discover", title: "Discover",
              subtitle: "Ignored collections & films — restore anything you hid from the Discover rails.", icon: "safari"),
        .init(id: "maintenance", label: "Maintenance", title: "Maintenance",
              subtitle: "App version, update status, and the reset-cache recovery tools for a stale UI.", icon: "wrench.adjustable"),
    ]

    static let top = ["general", "metadata"]

    static let groups: [SettingsGroupInfo] = [
        .init(id: "media", label: "Media Management", icon: "folder",
              children: ["roots", "naming", "filemanagement", "import"]),
        .init(id: "quality", label: "Quality", icon: "clock",
              children: ["qualitydefinitions", "formats", "releasefilters", "profiles", "defaultprofiles", "trash"]),
        .init(id: "access", label: "Access", icon: "checkmark.shield",
              children: ["access", "roles", "signin", "publicaccess", "security"]),
    ]

    static let sections: [SettingsSectionInfo] = [
        .init(id: "fetching", label: "Fetching",
              panels: ["clients", "indexers", "connect", "notifications", "instances"]),
        .init(id: "system", label: "System",
              panels: ["appearance", "system", "database", "backup", "logs", "about", "editions",
                       "experimental", "discover", "maintenance"]),
    ]

    private static let byId = Dictionary(uniqueKeysWithValues: panels.map { ($0.id, $0) })

    static func panel(_ id: String) -> SettingsPanelInfo? { byId[id] }

    /// The group or section label a panel sits under (search breadcrumbs).
    static func groupLabel(_ id: String) -> String {
        if let g = groups.first(where: { $0.children.contains(id) }) { return g.label }
        if let s = sections.first(where: { $0.panels.contains(id) }) { return s.label }
        return ""
    }
}

/// One Settings search result (the web's `settings-search.ts`).
struct SettingsSearchHit: Identifiable, Hashable {
    enum Kind { case field, page }
    let kind: Kind
    let panel: String
    let label: String
    let matchedKeyword: String?

    var id: String { "\(kind == .field ? "f" : "p")-\(panel)-\(label)" }

    var crumb: String {
        let group = SettingsNav.groupLabel(panel)
        if kind == .page { return group.isEmpty ? "open page" : "\(group) · open page" }
        let name = SettingsNav.panel(panel)?.label ?? panel
        return group.isEmpty ? name : "\(group) › \(name)"
    }

    /// Ranks field hits (label prefix, then substring, then keyword) above page
    /// hits; ties sort by label. Same rules as the web.
    static func search(_ query: String, limit: Int = 40) -> [SettingsSearchHit] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        var scored: [(SettingsSearchHit, Int)] = []
        for field in settingsFieldIndex {
            let label = field.label.lowercased()
            var score: Int?
            var matched: String?
            if label.hasPrefix(q) { score = 0 } else if label.contains(q) { score = 1 } else if let kw = field.keywords.first(where: { $0.contains(q) }) {
                score = 2
                matched = kw
            }
            guard let score else { continue }
            scored.append((SettingsSearchHit(kind: .field, panel: field.panel, label: field.label, matchedKeyword: matched), score))
        }
        for panel in SettingsNav.panels where "\(panel.label) \(panel.subtitle)".lowercased().contains(q) {
            scored.append((SettingsSearchHit(kind: .page, panel: panel.id, label: panel.label, matchedKeyword: nil), 3))
        }
        scored.sort { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0.label.localizedCompare($1.0.label) == .orderedAscending }
        return scored.prefix(limit).map(\.0)
    }
}
