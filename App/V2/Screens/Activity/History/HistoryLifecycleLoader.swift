import SwiftUI
import FusionhaKit

/// A story's lifecycle lane (v1 `HistoryLifecycleSheet`'s loading, kept as
/// it is): every History event of that episode or movie version, oldest
/// first, the sibling version for the HD / 4K switch, and the release-group
/// blocks a HELD step needs (`integrations.manage` only).
@MainActor
@Observable
final class HistoryLifecycleLoader {
    let story: HistoryStory
    var picked: Int?
    private(set) var lane: [HistoryEntry]?
    private(set) var siblings: [HistoryEntry] = []
    private(set) var blocks: [ReleaseGroupBlock] = []
    private(set) var error: String?

    init(story: HistoryStory) {
        self.story = story
    }

    /// The narrowest scope the story pins down (web `storyLifecycleScope`).
    var episodeId: Int? { story.events.first { $0.episodeId != nil }?.episodeId }
    private var scopeVersionId: Int? { story.events.first { $0.editionId != nil }?.editionId }
    var activeVersionId: Int? { picked ?? scopeVersionId }

    var events: [HistoryEntry] {
        HistoryLifecycleModel.events(lane ?? [], versionId: activeVersionId, episodeId: episodeId)
    }

    /// HD first, then 4K (the segmented switch's order).
    var versions: [HistoryLifecycleModel.Version] {
        HistoryLifecycleModel.switchVersions(events + siblings, activeId: activeVersionId, fallbackTier: story.tier)
            .sorted { $0.tier == $1.tier ? $0.id < $1.id : $0.tier == .hd }
    }

    var activeTier: QualityTier? {
        versions.first { $0.id == activeVersionId }?.tier ?? story.tier
    }

    var loaded: Bool { lane != nil }

    func load(client: APIClient?, canManage: Bool) async {
        guard let client else { return }
        // A story whose title left the library has no lane to load (the open
        // Duo can pick one); say so instead of spinning.
        guard let itemId = story.mediaItemId else {
            error = "This title is no longer in your library."
            return
        }
        error = nil
        do {
            let page = try await client.historyLifecycle(itemId: itemId, episodeId: episodeId, versionId: activeVersionId)
            lane = page.items.sorted { $0.createdAt < $1.createdAt }
        } catch let e as APIError where e.status == 404 {
            error = "This title is no longer in your library."
            return
        } catch {
            self.error = "The lifecycle could not be loaded. Check the server and try again."
            return
        }
        if siblings.isEmpty,
           let all = try? await client.historyLifecycle(itemId: itemId, episodeId: episodeId, versionId: nil) {
            siblings = all.items
        }
        if events.contains(where: { $0.eventType == "HELD" }), canManage, let all = try? await client.releaseGroupBlocks() {
            blocks = all
        }
    }
}
