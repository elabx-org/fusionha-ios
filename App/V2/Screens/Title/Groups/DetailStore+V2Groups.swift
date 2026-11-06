import Foundation
import FusionhaKit

/// The title's release-group blocks (v2's Release groups sheet and the rows'
/// "Block <GROUP>"): `GET /api/v1/release-groups/blocks?media_item_id=`
/// (this title's and the global ones), a manual block (`reason: manual`,
/// `source: api`) and Unblock. The routes need `integrations.manage`.
extension DetailStore {
    func loadGroupBlocks() async {
        guard let client else { return }
        if let rows = try? await client.releaseGroupBlocks(mediaItemId: itemId) {
            groupBlocks = TitleGroupBlocks.applying(rows, itemId: itemId)
        }
    }

    /// The block that stops `group` on this title, if one is loaded.
    func groupBlock(for group: String?) -> ReleaseGroupBlock? {
        TitleGroupBlocks.block(for: group, in: groupBlocks ?? [], itemId: itemId)
    }

    /// Blocks `group` for this title or everywhere; nil when it worked, else what went wrong.
    func blockReleaseGroup(_ group: String, everywhere: Bool, note: String?) async -> String? {
        guard let client else { return ErrorCopy.generic }
        let note = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let row = try await client.addReleaseGroupBlock(
                group, mediaItemId: TitleGroupBlocks.mediaItemId(everywhere: everywhere, itemId: itemId),
                note: note?.isEmpty == false ? note : nil, source: "api")
            groupBlocks = TitleGroupBlocks.applying(TitleGroupBlocks.merged(groupBlocks ?? [], adding: row), itemId: itemId)
            return nil
        } catch {
            return Self.groupError(error)
        }
    }

    /// Unblock: nil when it worked, else what went wrong.
    func unblockReleaseGroup(_ block: ReleaseGroupBlock) async -> String? {
        guard let client else { return ErrorCopy.generic }
        do {
            try await client.deleteReleaseGroupBlock(id: block.id)
            groupBlocks = groupBlocks?.filter { $0.id != block.id }
            return nil
        } catch {
            return Self.groupError(error)
        }
    }

    /// Every group seen on this title, in order: its files, its history,
    /// then the releases of an interactive search still parked in the store.
    var seenReleaseGroups: [String?] {
        guard let detail else { return [] }
        var out: [String?] = detail.editions.map { $0.movieFile?.releaseGroup }
        for episode in detail.allEpisodes {
            out += (episode.files ?? []).map { $0.file?.releaseGroup }
        }
        for entry in detail.history ?? [] {
            out.append(entry.chips?.first(where: { $0.kind == "group" })?.label)
        }
        if let search = drafts.value("search.model", as: InteractiveSearchModel.self) {
            for rows in search.results.values { out += rows.map(\.releaseGroup) }
        }
        return out
    }

    private static func groupError(_ error: Error) -> String {
        if let code = (error as? APIError)?.code, let text = HeldCopy.errorCopy[code] { return text }
        return ErrorCopy.message(for: error, fallback: "Couldn’t change the release group block.")
    }
}
