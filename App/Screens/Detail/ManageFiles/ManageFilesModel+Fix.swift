import Foundation
import FusionhaKit

/// Needs you's Fix mode (owner-approved mock, 2026-11-08) on top of the
/// Manage files model: Stop monitoring without deleting anything. Replace
/// runs in the background (`V2ReplaceRun`).
extension ManageFilesModel {
    /// Unmonitors the episodes the files cover; the files stay as they are.
    func stopMonitoringEpisodes(_ targets: [ManagedFileItem]) async {
        guard let client else { return }
        let ids = ManageEpisodes.episodeIds(targets, detail: detail)
        guard !ids.isEmpty else { return }
        busy = true
        defer { busy = false }
        do {
            let result = try await client.setEpisodesMonitored(itemId: detail.id, episodeIds: ids, monitored: false)
            unmonitored.formUnion(result.updatedIds)
            await finish(ids.count == 1 ? "Stopped monitoring the episode." : "Stopped monitoring \(ids.count) episodes.",
                         stood: nil, failed: 0, failedText: "")
        } catch {
            note = Note(text: "Couldn’t stop monitoring. Try again.", failed: true)
        }
    }
}
