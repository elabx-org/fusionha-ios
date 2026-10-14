import Foundation

// The queue card's words and stage rail (web `card-text.ts`, `card-mode.ts`,
// `stage-rail.ts`, mock v4). Pure.

public enum QueueCardText {
    private static func cap(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }

    /// The held reason in Manual Import's words ("Smaller than its name
    /// says"), plus its guard ("would replace your 4K FUZEER copy").
    public static func heldReason(_ item: QueueItem) -> (lead: String, guard: String?) {
        let d = item.heldDetail
        let short: String
        if d?.kind == "mislabeled_hdr" {
            short = "not an upgrade"
        } else if d?.mislabeled == true {
            short = "smaller than its name says"
        } else {
            short = item.heldReason ?? "needs a manual import"
        }
        return (cap(short), ManualImportHeldStrip.guardLine(d?.currentGroup, tier: item.tier.rawValue, edition: item.edition))
    }

    /// Beside the title: the episode label, else the movie's year.
    public static func subtitle(_ item: QueueItem) -> String? {
        item.episodeLabel ?? item.parsed?.year.map(String.init)
    }

    /// "grabbed 16m ago".
    public static func grabbedAgo(_ ageSeconds: Double?) -> String {
        let secs = max(0, Int((ageSeconds ?? 0).rounded()))
        if secs < 60 { return "grabbed just now" }
        let mins = secs / 60
        if mins < 60 { return "grabbed \(mins)m ago" }
        let hours = mins / 60
        if hours < 24 { return "grabbed \(hours)h ago" }
        return "grabbed \(hours / 24)d ago"
    }

    /// "Extended · HD"; Standard reads as the tier alone unless the title has
    /// several editions ("Standard · HD").
    public static func versionLabel(_ item: QueueItem) -> String {
        VersionLabel.text(tier: item.tier, edition: item.edition, multipleEditions: item.hasMultipleEditions == true)
            ?? item.tier.word
    }

    /// "Miatrix (Prowlarr)" → "Miatrix" and "Synced from Prowlarr".
    public static func splitIndexer(_ name: String) -> (name: String, via: String?) {
        guard name.hasSuffix(")"), let open = name.range(of: " (", options: .backwards) else { return (name, nil) }
        let via = name[open.upperBound..<name.index(before: name.endIndex)]
        return (String(name[..<open.lowerBound]), "Synced from \(via)")
    }

    public static func isTorrent(_ item: QueueItem) -> Bool { item.protocol?.uppercased() == "TORRENT" }
}

/// One node of the card's stage rail.
public struct QueueRailNode: Sendable, Hashable, Identifiable {
    public enum State: Sendable, Hashable { case done, active, todo, off, fail, held }
    public let key: String
    public let label: String
    public let state: State
    /// Beside an active label instead of "working…" (linking count, %).
    public var count: String?
    /// What a long-press explains (a skipped stage, the collapsed "Linked").
    public var tip: String?
    public var id: String { key }

    public init(_ key: String, _ label: String, _ state: State, count: String? = nil, tip: String? = nil) {
        self.key = key
        self.label = label
        self.state = state
        self.count = count
        self.tip = tip
    }
}

/// Decypharr's nodes, a seam, then fusionha's own import node.
public struct QueueRailModel: Sendable, Hashable {
    public enum ImportState: Sendable, Hashable { case todo, active, held, done }
    public let nodes: [QueueRailNode]
    public let importState: ImportState

    public var importNode: QueueRailNode {
        switch importState {
        case .todo: return QueueRailNode("import", "Import", .todo)
        case .active: return QueueRailNode("import", "Importing", .active)
        case .held: return QueueRailNode("import", "Import held", .held)
        case .done: return QueueRailNode("import", "Imported", .done)
        }
    }
}

public enum QueueRail {
    static let stageLabels = ["queued": "Queued", "parsing": "Parsing", "downloading": "Downloading",
                              "processed": "Processed", "linking": "Linking", "caching": "Caching",
                              "probing": "Probing", "validating": "Validating", "complete": "Complete"]

    public static func stageLabel(_ key: String?) -> String {
        guard let key else { return "Working" }
        return stageLabels[key] ?? key.prefix(1).uppercased() + key.dropFirst()
    }

    /// Whether a finished download went through decypharr (a symlink, not a copy).
    public static func viaDecypharr(_ item: QueueItem) -> Bool {
        if item.stages?.route != nil { return true }
        return item.downloadClient?.range(of: "decypharr", options: .caseInsensitive) != nil
    }

    /// Every stage decypharr ran, for the collapsed node's tip.
    static func linkedTip(_ item: QueueItem) -> String {
        let keys: [String]
        if let steps = item.stages?.steps, !steps.isEmpty {
            keys = steps.filter(\.runs).map(\.key)
        } else if QueueCardText.isTorrent(item) {
            keys = ["downloading", "linking", "caching", "complete"]
        } else {
            keys = ["queued", "parsing", "processed", "linking", "caching", "validating", "complete"]
        }
        return keys.map { stageLabels[$0] ?? $0 }.joined(separator: " · ")
    }

    /// Grabbed ✓ → Linked by decypharr ✓ (or Downloaded ✓).
    static func finishedNodes(_ item: QueueItem) -> [QueueRailNode] {
        let linked = viaDecypharr(item)
            ? QueueRailNode("linked", "Linked by decypharr", .done, tip: linkedTip(item))
            : QueueRailNode("downloaded", "Downloaded", .done)
        return [QueueRailNode("grabbed", "Grabbed", .done), linked]
    }

    /// A held download: everything before import is done, import waits on you.
    public static func held(_ item: QueueItem) -> QueueRailModel {
        QueueRailModel(nodes: finishedNodes(item), importState: .held)
    }

    /// The import is running.
    public static func importing(_ item: QueueItem) -> QueueRailModel {
        QueueRailModel(nodes: finishedNodes(item), importState: .active)
    }
}
