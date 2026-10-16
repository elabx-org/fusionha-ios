import Foundation

// The queue card's words and stage rail (web `card-text.ts`, `card-mode.ts`,
// `stage-rail.ts`, mock v4). Pure.

public enum QueueCardText {
    private static func cap(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }

    /// The held card's reason (web `heldReason`, 0.4.203): `lead` is the
    /// server's `held.short`, except code `other`, whose own path-free sentence
    /// says more than "needs a look"; `text` is `held.text` as a line under it
    /// when there is no detail panel to explain it, unless it repeats the lead.
    /// Older servers send no copy and keep the Manual Import strip's words.
    public static func heldReason(_ item: QueueItem) -> (lead: String, guard: String?, text: String?) {
        let d = item.heldDetail
        let guardLine = ManualImportHeldStrip.guardLine(d?.currentGroup, tier: item.tier.rawValue, edition: item.edition)
        guard let held = item.held else { return (cap(legacyShort(item)), guardLine, nil) }
        let lead = cap(held.code == "other" ? held.line : held.short)
        let text = d == nil && norm(held.text) != norm(lead) ? held.text : nil
        return (lead, guardLine, text)
    }

    private static func norm(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespaces)
        while let last = t.last, ".!?".contains(last) { t.removeLast() }
        return t.lowercased()
    }

    private static func legacyShort(_ item: QueueItem) -> String {
        let d = item.heldDetail
        if d?.kind == "mislabeled_hdr" { return "not an upgrade" }
        if d?.mislabeled == true { return "smaller than its name says" }
        return item.heldReason ?? "needs a manual import"
    }

    /// The hold in two or three words, for the Live Activity's one-line rows:
    /// the server's `held.short` (0.4.203+). Older servers: classified like
    /// fusionha's `held_history.reason_code_for`, the detail's kind first, then
    /// the reason's known text.
    public static func heldTag(_ item: QueueItem) -> String {
        if let short = item.held?.short, !short.isEmpty { return short }
        let d = item.heldDetail
        if d?.kind == "mislabeled_hdr" { return "no HDR in file" }
        if d?.mislabeled == true || d?.kind == "mislabeled_resolution" {
            return d?.claimedResolution.map { "not really \($0)p" } ?? "smaller than named"
        }
        if d?.kind == "not_an_upgrade" { return "not an upgrade" }
        let low = (item.heldReason ?? "").lowercased()
        if low.hasPrefix("corrupt/incomplete") { return "corrupt file" }
        if low.hasPrefix("the file's resolution belongs to a different tier") { return "wrong tier" }
        if low.hasPrefix("the correct-tier edition's quality profile does not allow") { return "quality not allowed" }
        if low.contains("would orphan other episodes of a multi-episode file") { return "splits an episode pair" }
        if low.contains("(indeterminate)") { return "couldn't check file" }
        if low.contains("not an upgrade") { return "not an upgrade" }
        // Holds fusionha's reason_code files under "other", by their own text.
        if low.hasPrefix("not really ") { return "smaller than named" }
        if low.hasPrefix("release resolution could not be read") { return "unnamed resolution" }
        if low.contains("numbering review") { return "numbering check" }
        if low.hasPrefix("sample: runtime") { return "too short" }
        if low.hasPrefix("another import was writing this slot") { return "slot was busy" }
        if low.hasPrefix("recording the import failed") { return "import failed" }
        if low.hasPrefix("the imported file could not be put in place") { return "couldn't place file" }
        if low.hasPrefix("the current file changed") { return "current file changed" }
        return "needs a look"
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

extension QueueRail {
    /// Decypharr's nodes for a phase job, in the plan's order: the current
    /// stage is "working…" (or the linking count), a skipped stage is off, a
    /// failed job holds the furthest stage it reached.
    public static func phaseNodes(_ stages: QueueStages, failed: Bool = false, retrying: Bool = false) -> [QueueRailNode] {
        let steps = stages.steps ?? []
        let active = steps.filter(\.runs).map(\.key)
        let at = stages.current.flatMap { active.firstIndex(of: $0) } ?? -1
        let finished = stages.current == "complete" && stages.failed != true
        let linking = stages.linkingDone.flatMap { d in stages.linkingTotal.map { "\(d)/\($0)" } }
        return steps.map { s in
            let label = stageLabels[s.key] ?? s.key
            guard s.runs else { return QueueRailNode(s.key, label, .off, tip: "\(label) is turned off in decypharr") }
            let i = active.firstIndex(of: s.key) ?? -1
            var state: QueueRailNode.State = .todo
            if finished || (at >= 0 && i < at) {
                state = .done
            } else if i == at {
                state = retrying ? .active : (failed || stages.failed == true ? .fail : .active)
            }
            var node = QueueRailNode(s.key, state == .fail ? "Failed at \(label.lowercased())" : label, state)
            if state == .active && retrying { node.count = "retrying…" }
            if state == .active && s.key == "linking", let linking { node.count = linking }
            return node
        }
    }

    public enum Kind: Sendable, Hashable { case bytes(pct: Int), waiting, other, phase, retrying, failed, stuck }

    /// The rail for one card, by how it renders (web `railFor`).
    public static func model(_ item: QueueItem, _ kind: Kind) -> QueueRailModel {
        let grabbed = QueueRailNode("grabbed", "Grabbed", .done)
        switch kind {
        case .bytes(let pct):
            return QueueRailModel(nodes: [grabbed, QueueRailNode("downloading", "Downloading", .active,
                                                                  count: item.stalled ? "\(pct)% · stalled" : "\(pct)%")],
                                  importState: .todo)
        case .waiting:
            return QueueRailModel(nodes: [grabbed, QueueRailNode("client", "Waiting for the client", .active, count: "checking…")],
                                  importState: .todo)
        case .stuck:
            return QueueRailModel(nodes: [grabbed, QueueRailNode("download", "Download", .fail)], importState: .todo)
        default:
            guard kind != .other, let stages = item.stages, !(stages.steps ?? []).isEmpty else {
                let node = QueueRailNode("download", kind == .failed ? "Failed at download" : "Download",
                                         kind == .failed ? .fail : .active, count: kind == .retrying ? "retrying…" : nil)
                return QueueRailModel(nodes: [grabbed, node], importState: .todo)
            }
            return QueueRailModel(nodes: phaseNodes(stages, failed: kind == .failed, retrying: kind == .retrying),
                                  importState: .todo)
        }
    }

    /// Finished stages out of those that run (never `phase_percent`).
    public static func ring(_ stages: QueueStages?) -> (done: Int, total: Int)? {
        guard let stages, let total = stages.total, total > 0 else { return nil }
        return (min(stages.completed ?? 0, total), total)
    }
}
