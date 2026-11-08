import Foundation
import FusionhaKit

/// Needs you's Fix mode (owner-approved mock, 2026-11-08) on top of the
/// Manage files model: Replace with the release blocklisted, and Stop
/// monitoring without deleting anything.
extension ManageFilesModel {
    /// Files in `blocklisting` go through the single-file delete with the
    /// release blocklisted and a search; the rest through `replace` (the
    /// guarded replace, remove-and-regrab for absent records, forced for
    /// damaged files).
    func fixReplace(_ targets: [ManagedFileItem], blocklisting: Set<Int>) async {
        guard let client, !targets.isEmpty else { return }
        let listed = targets.filter { blocklisting.contains($0.id) }
        let rest = targets.filter { !blocklisting.contains($0.id) }
        var done = 0, failed = 0
        if !listed.isEmpty {
            busy = true
            for t in listed {
                do {
                    try await client.deleteFile(id: t.id, blocklist: true, search: true)
                    done += 1
                } catch {
                    failed += 1
                }
            }
            busy = false
        }
        if !rest.isEmpty {
            await replace(rest)
            if failed > 0 {
                note = Note(text: "Couldn’t replace \(failed == 1 ? "1 file" : "\(failed) files"). Try again.", failed: true)
            }
            return
        }
        await finish(done > 0 ? "Release blocklisted. Searching for \(done == 1 ? "a new copy" : "new copies")." : nil,
                     stood: nil, failed: failed,
                     failedText: "Couldn’t replace \(failed == 1 ? "the file" : "\(failed) files"). Try again.")
    }

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
