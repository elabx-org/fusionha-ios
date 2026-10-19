import SwiftUI
import FusionhaKit

// The queue's wash per card state (web `card-content.tsx` `WASH`): held and
// retrying need you (amber), stuck and failed are red, a waiting row is grey,
// everything still moving is cyan, a stalled transfer included.

extension QueueCardMode {
    var wash: QueueWashStatus {
        switch self {
        case .held, .retrying: return .attention
        case .stuck, .failed: return .failed
        case .waiting: return .queued
        case .importing, .phase, .bytes, .other: return .working
        }
    }

    /// The group header's states summary word and tone (`group-model.ts` LABEL).
    var stateLabel: (text: String, tone: QueueStateTone) {
        switch self {
        case .held: return ("held", .warn)
        case .retrying: return ("retrying", .warn)
        case .stuck: return ("stuck", .bad)
        case .failed: return ("failed", .bad)
        case .importing: return ("importing", .neutral)
        case .phase: return ("in progress", .neutral)
        case .bytes, .other: return ("downloading", .neutral)
        case .waiting: return ("waiting", .neutral)
        }
    }

    /// Failures first, as the web orders the summary.
    static let summaryOrder: [QueueCardMode] = [.failed, .stuck, .held, .retrying, .waiting, .bytes, .other, .phase, .importing]
}

enum QueueStateTone { case bad, warn, neutral }

extension QueueWashStatus {
    /// The wash as a status tone, so Monochrome draws its pattern.
    var tone: StatusTone {
        switch self {
        case .failed: return StatusTone(.danger)
        case .attention: return StatusTone(.stuck)
        case .working: return StatusTone(.grab)
        case .queued: return StatusTone(color: Theme.dim)
        }
    }
}

extension QueueLogic {
    /// `queueWashStatus`: the card's wash from its state.
    static func wash(_ item: QueueItem) -> StatusTone { QueueCardMode(item).wash.tone }

    /// `groupWash`: the most urgent member's wash.
    static func groupWash(_ downloads: [QueueItem]) -> StatusTone {
        QueueWashStatus.mostUrgent(downloads.map { QueueCardMode($0).wash }).tone
    }
}
