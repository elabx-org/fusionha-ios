import SwiftUI
import FusionhaKit

// The story types and the story value (web `activity-format.ts`).

enum HistoryStoryType: String, CaseIterable, Sendable {
    case upgraded, added, grabbed, failed, deleted, other

    var label: String {
        switch self {
        case .upgraded: return "Upgraded"
        case .added: return "Added"
        case .grabbed: return "Grabbed"
        case .failed: return "Failed"
        case .deleted: return "Deleted"
        case .other: return "Updated"
        }
    }

    var color: Color {
        switch self {
        case .upgraded: return Theme.edition
        case .added: return Theme.done
        case .grabbed: return Theme.grab
        case .failed: return Theme.danger
        case .deleted: return Theme.miss
        case .other: return Theme.mut
        }
    }

    var wash: StatusTone? {
        switch self {
        case .grabbed, .upgraded: return StatusTone(.done)
        case .added: return StatusTone(.grab)
        case .deleted, .failed: return StatusTone(.danger)
        case .other: return nil
        }
    }

    /// The story's status token (its timeline node and KPI dot under Monochrome).
    var mono: MonoToken? {
        switch self {
        case .upgraded: return .edition
        case .added: return .done
        case .grabbed: return .grab
        case .failed: return .danger
        case .deleted: return .miss
        case .other: return nil
        }
    }

    var icon: String {
        switch self {
        case .upgraded: return "arrow.up"
        case .added: return "checkmark"
        case .grabbed: return "arrow.down"
        case .failed: return "xmark"
        case .deleted: return "trash"
        case .other: return "pencil"
        }
    }

    /// historyStoryActions: open / search / blocklist.
    var actions: (open: Bool, search: Bool, blocklist: Bool) {
        switch self {
        case .upgraded, .added, .grabbed: return (true, false, true)
        case .failed: return (false, true, true)
        case .deleted: return (false, true, false)
        case .other: return (true, false, false)
        }
    }
}

struct HistoryStory: Identifiable, Equatable, Sendable {
    let key: String
    let type: HistoryStoryType
    let time: String
    let date: Date
    let mediaItemId: Int?
    let title: String
    let episodeLabel: String?
    let tier: QualityTier?
    /// The version's cut; nil for Standard.
    var edition: String? = nil
    let posterUrl: String?
    let oldQuality: String?
    let oldCf: Int?
    let newQuality: String?
    let newSize: Double?
    let newCf: Int?
    let indexer: String?
    let downloadClient: String?
    let failReason: String?
    let releaseTitle: String?
    let chips: [HistoryChip]
    let actionEntry: HistoryEntry
    let events: [HistoryEntry]
    var id: String { key }
}
