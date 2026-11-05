import Foundation
import FusionhaKit

/// The words and glyphs of a v2 story card (mock activity-log.js `STORIES`):
/// "Upgraded to Bluray-1080p Remux", "Replaced WEB-DL 1080p · custom-format
/// 4,050 (+2,800)", "Grabbed 17:15 · imported 17:16".
enum V2StoryCopy {
    /// The version's ticket: filled once a file landed, an outline for a
    /// failure or a grab still on its way (the letters name the version).
    static func badge(_ type: HistoryStoryType) -> EditionBadgeState {
        switch type {
        case .upgraded, .added, .other: return .onDisk
        case .grabbed, .failed, .deleted: return .missing
        }
    }

    static func glyph(_ type: HistoryStoryType) -> String {
        switch type {
        case .upgraded: return "arrow.up"
        case .added: return "checkmark"
        case .grabbed: return "arrow.down"
        case .failed: return "xmark.circle"
        case .deleted: return "trash"
        case .other: return "pencil"
        }
    }

    static func headline(_ story: HistoryStory) -> String {
        let new = story.newQuality.map { ActFmt.quality($0) }
        switch story.type {
        case .upgraded: return new.map { "Upgraded to \($0)" } ?? "Upgraded"
        case .added: return new.map { "Imported \($0)" } ?? "Imported"
        case .grabbed: return new.map { "Grabbed \($0)" } ?? "Grabbed"
        case .deleted: return story.oldQuality.map { "Deleted \(ActFmt.quality($0))" } ?? "Deleted"
        case .failed:
            let fails = story.events.filter { HistoryLogic.rawFilter($0.eventType) == "failed" }.count
            if fails > 1 { return "Download failed \(fails == 2 ? "twice" : "\(fails) times")" }
            if let reason = failReason(story) { return FailureCopy.format(reason, context: .download).title }
            return "Download failed"
        case .other: return story.type.label
        }
    }

    static func detail(_ story: HistoryStory) -> String? {
        var parts: [String] = []
        switch story.type {
        case .upgraded:
            if let old = story.oldQuality { parts.append("Replaced \(ActFmt.quality(old))") }
            if let cf = HistoryLogic.cfText(story.newCf, story.oldCf) { parts.append(cf) }
        case .failed:
            if let reason = failReason(story) { parts.append(FailureCopy.format(reason, context: .download).detail) }
        default:
            if let size = story.newSize { parts.append(ActFmt.bytes(size)) }
            if let cf = HistoryLogic.cfText(story.newCf, nil) { parts.append(cf) }
        }
        if let client = story.downloadClient { parts.append(client) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "Grabbed 17:15 · imported 17:16"; longer stories say how many events.
    static func events(_ story: HistoryStory) -> String {
        let sorted = story.events.sorted { $0.createdAt < $1.createdAt }
        guard sorted.count <= 3 else { return "\(sorted.count) events" }
        let parts = sorted.enumerated().map { index, event in
            let label = HistoryLogic.eventMeta(event.eventType).label
            let time = V2QueueTime.clock(event.createdAt) ?? ActFmt.relative(event.createdAt)
            return "\(index == 0 ? label : label.lowercased()) \(time)"
        }
        return parts.isEmpty ? story.type.label : parts.joined(separator: " · ")
    }

    private static func failReason(_ story: HistoryStory) -> String? {
        story.failReason ?? story.actionEntry.data?.text("reason")
    }
}
