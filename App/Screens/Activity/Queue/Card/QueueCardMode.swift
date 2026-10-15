import SwiftUI
import FusionhaKit

/// How one queue card renders (web `card-mode.ts`). Held has its own card
/// (`QueueHeldCard`); every other mode is a `QueueStateCard`.
enum QueueCardMode: Equatable {
    case held, stuck, failed, retrying, importing, phase, bytes, waiting, other

    init(_ item: QueueItem) {
        switch item.cockpitState {
        case .held: self = .held; return
        case .stuck: self = .stuck; return
        case .importing: self = .importing; return
        default: break
        }
        switch item.lane {
        case .retrying: self = item.phaseTerminal == true ? .failed : .retrying
        case .working: self = item.phase == "complete" || item.phase == "importing" ? .importing : .phase
        case .byte:
            if item.warning != nil {
                self = .waiting
            } else if Self.isFullDownload(item) {
                self = .bytes
            } else {
                self = .other
            }
        }
    }

    /// A genuine byte transfer: the plan says `bytes`, or there is no phase
    /// and the client reports it downloading.
    static func isFullDownload(_ item: QueueItem) -> Bool {
        if let mode = item.stages?.mode { return mode == "bytes" }
        return item.phase == nil && item.status.lowercased() == "downloading"
    }

    /// Stuck or failed: blocklisting also searches, and removing offers a search.
    var isBroken: Bool { self == .stuck || self == .failed }
}
