import Foundation

/// The queue's truthfulness rules (fusionha's decypharr phase-mode contract,
/// handoff §4.2), kept pure so they are tested here rather than in views.
///
/// - A job is in *phase mode* when `phase` is present and isn't `downloading`;
///   otherwise *byte mode* (speed, percent, ETA). Phase mode shows no MB/s, no
///   percent and no time ETA.
/// - The ring is completed stages / total stages; the current stage is
///   indeterminate. `phase_percent` is a non-linear weighting and is never drawn.
/// - The only within-stage number is Linking, parsed from `Linking (n/total)`.
/// - An errored job holds at the last stage the client saw; a cold poll that is
///   already errored shows "failed" with no stage position.
public enum QueueRules {

    // MARK: Linking

    public struct Linking: Equatable, Sendable {
        public let done: Int
        public let total: Int
        public var fraction: Double { Double(done) / Double(total) }
        public var label: String { "\(done) / \(total)" }
    }

    /// `Linking (n/total)` only. `Pushing (n/total)` is a storage push, not
    /// linking progress, and `(0/0)` means nothing yet: both are nil.
    public static func linking(step: String?) -> Linking? {
        guard let step,
              let match = step.firstMatch(of: #/^Linking \((\d+)/(\d+)\)$/#),
              let done = Int(match.1), let total = Int(match.2), total > 0 else { return nil }
        return Linking(done: min(done, total), total: total)
    }

    // MARK: Modes

    public static func isPhaseMode(phase: String?) -> Bool {
        guard let phase, !phase.isEmpty else { return false }
        return phase != "downloading"
    }

    /// Byte mode is only for real transfers: a grab the client hasn't started
    /// reads `downloading` with zero bytes and shows "Waiting for the client".
    public static func hasRealBytes(progress: Double, size: Double, sizeleft: Double) -> Bool {
        progress > 0 || (size > 0 && sizeleft < size)
    }

    public static func isFailed(phase: String?, phaseTerminal: Bool?) -> Bool {
        phase == "error" || (phaseTerminal == true && phase != nil && phase != "complete")
    }

    // MARK: Stages

    public enum Route: Sendable { case debrid, usenet }

    public static func route(protocol proto: String?) -> Route {
        proto?.lowercased() == "torrent" ? .debrid : .usenet
    }

    /// The rail for a route. Probing and Validating are optional and drawn only
    /// while they are (or were last) the live phase. Importing is fusionha's own
    /// final stage.
    public static func stages(route: Route, including phase: String? = nil) -> [String] {
        switch route {
        case .debrid:
            return ["Downloading", "Linking", "Caching", "Importing"]
        case .usenet:
            var rail = ["Parsing", "Processed", "Linking", "Caching"]
            if phase == "probing" { rail.append("Probing") }
            if phase == "validating" { rail.append("Validating") }
            rail.append("Importing")
            return rail
        }
    }

    static func label(for phase: String?) -> String? {
        switch phase {
        case "downloading": return "Downloading"
        case "queued", "parsing": return "Parsing"
        case "processed": return "Processed"
        case "linking": return "Linking"
        case "caching": return "Caching"
        case "probing": return "Probing"
        case "validating": return "Validating"
        case "complete", "importing": return "Importing"
        default: return nil
        }
    }

    public struct StageState: Equatable, Sendable {
        public let stages: [String]
        /// The live (or, when failed, last seen) stage; nil for a cold failure.
        public let current: Int?
        /// Stages completed before `current`.
        public let completed: Int
        public let failed: Bool
        public var total: Int { stages.count }
        /// The ring's value: completed / total, never `phase_percent`.
        public var ring: Double { total == 0 ? 0 : Double(completed) / Double(total) }
        public var currentLabel: String? { current.map { stages[$0] } }
    }

    /// Where a job stands on its rail. `lastSeenPhase` is the client's memory of
    /// the furthest live phase (or the server's `last_phase` once it sends one),
    /// used only when the job has failed.
    public static func state(protocol proto: String?, phase: String?, phaseTerminal: Bool?,
                             lastSeenPhase: String? = nil) -> StageState {
        let route = route(protocol: proto)
        let failed = isFailed(phase: phase, phaseTerminal: phaseTerminal)
        let shown = failed ? lastSeenPhase : phase
        let rail = stages(route: route, including: shown)
        guard let label = label(for: shown), let index = rail.firstIndex(of: label) else {
            return StageState(stages: rail, current: nil, completed: 0, failed: failed)
        }
        return StageState(stages: rail, current: index, completed: index, failed: failed)
    }

    /// Updates the client's memory of each job's furthest live phase: errors
    /// never overwrite it, and jobs that left the queue are forgotten.
    public static func remember(_ memory: [Int: String], items: [(id: Int, phase: String?)]) -> [Int: String] {
        var next: [Int: String] = [:]
        for item in items {
            if let phase = item.phase, label(for: phase) != nil { next[item.id] = phase }
            else if let kept = memory[item.id] { next[item.id] = kept }
        }
        return next
    }
}
