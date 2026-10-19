import Foundation
import FusionhaKit

/// The queue's card sections, in the web's order and words (fusionha 0.4.198,
/// `queue-groups.ts` / `QueueCardGroups.tsx`): Needs you · Importing · In
/// progress · Downloading · Failed. Plain queued slots stay in Up next.
enum QueueSection: String, CaseIterable {
    case needs, importing, progress, downloading, failed, upnext

    /// The sections drawn as cards (Up next and Just finished draw their own way).
    static let cardSections: [QueueSection] = [.needs, .importing, .progress, .downloading, .failed]

    var label: String {
        switch self {
        case .needs: return "Needs you"
        case .importing: return "Importing"
        case .progress: return "In progress"
        case .downloading: return "Downloading"
        case .failed: return "Failed"
        case .upnext: return "Up next"
        }
    }

    var hint: String? {
        switch self {
        case .needs: return "Paused until you decide"
        case .progress: return "decypharr is linking these; nothing is downloaded"
        case .downloading: return "Full downloads, real bytes"
        case .failed: return "Retrying, or searching for another release"
        case .importing, .upnext: return nil
        }
    }

    /// Only In progress and Downloading fold a title's 4K + HD into one pair card.
    var pairsVersions: Bool { self == .progress || self == .downloading }

    /// Which section one download's card renders in (`queueCardGroup`).
    static func of(_ item: QueueItem) -> QueueSection {
        let status = item.status.lowercased()
        if status == "held" || item.needsAttention == true { return .needs }
        if item.phaseTerminal == true, let phase = item.phase, phase != "complete" { return .failed }
        if item.phase == "importing" || item.phase == "complete" || status == "completed" { return .importing }
        if item.phase == "queued" { return .upnext }
        let phaseMode = item.stages.map { $0.mode == "phase" } ?? (item.phase != nil && item.phase != "downloading")
        if phaseMode { return .progress }
        // A grabbed-but-not-yet-in-the-client row (`warning`) stays a card
        // reading "Waiting for the client" rather than a silent Up next slot.
        if ["queued", "delay", "pending", "paused"].contains(status), item.warning == nil, !item.stalled { return .upnext }
        return .downloading
    }
}

extension QueueLogic {
    /// One section's cards, grouped as the web groups them; Downloading is
    /// ordered by ETA (the web dropped the soonest highlight, ruling A7).
    static func entries(_ items: [QueueItem], section: QueueSection, telemetry: [Int: QueueTelemetry]) -> [Entry] {
        let groups = group(items, section: section.rawValue, pairs: section.pairsVersions)
        if section == .downloading {
            let split = split(groups, telemetry: telemetry)
            return split.active + split.upNext.map { .solo($0, eta: nil) }
        }
        return groups.map { g in
            g.downloads.count == 1 ? .solo(g.downloads[0], eta: telemetry[g.downloads[0].id]?.eta) : .group(g, eta: nil)
        }
    }
}
