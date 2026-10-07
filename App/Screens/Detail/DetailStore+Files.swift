import Foundation
import FusionhaKit

// File, history and delete actions.
extension DetailStore {
    // MARK: Files and history

    /// #82 dead-link "Search replacement": delete the version's dead file(s), then re-grab.
    func replaceDead(_ edition: DetailEdition) async {
        guard let client, let title = detail?.title else { return }
        flash = SearchFlash(phase: .searching, scope: "\(title) — replacing dead file(s)")
        defer { flash = nil }
        do {
            try await client.replaceDeadVersion(versionId: edition.id)
            await reload()
        } catch {
            show("Couldn't replace the dead file", variant: .error)
        }
    }

    func deleteFile(_ fileId: Int, blocklist: Bool) async {
        guard let client else { return }
        do {
            try await client.deleteFile(id: fileId, blocklist: blocklist)
            show(blocklist ? "File deleted and release blocklisted" : "File deleted", variant: .success)
            await reload()
        } catch {
            show("Couldn't delete the file", variant: .error)
        }
    }

    func cleanupLink(_ fileId: Int) async {
        guard let client else { return }
        do {
            try await client.cleanupLink(fileId: fileId)
            show("Dead link cleaned up", variant: .success)
            await reload()
        } catch {
            show("Couldn't clean up the link", variant: .error)
        }
    }

    func regrab(_ entry: HistoryEntry) async {
        guard let client else { return }
        do {
            try await client.regrab(historyId: entry.id)
            show("Re-grabbing \(entry.sourceTitle ?? "release")", variant: .success)
            await reload()
        } catch {
            show("Couldn't re-grab that release", variant: .error)
        }
    }

    func deleteItem(deleteFiles: Bool) async -> Bool {
        guard let client, let title = detail?.title else { return false }
        do {
            try await client.deleteItem(id: itemId, deleteFiles: deleteFiles)
            deleted = true
            return true
        } catch {
            show("Couldn't delete \(title)", variant: .error)
            return false
        }
    }
}
