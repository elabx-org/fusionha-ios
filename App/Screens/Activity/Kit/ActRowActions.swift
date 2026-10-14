import UIKit
import SwiftUI
import FusionhaKit

// MARK: Shared row actions (use-blocklist-action / use-regrab-action / copy)

@MainActor
enum ActActions {
    /// `POST /api/v1/blocklist` with the web's toasts. `undo` offers an Undo that
    /// lifts the new entry again.
    static func blocklist(_ client: APIClient?, _ toaster: ActToaster, _ body: BlocklistCreate,
                          offerUndo: Bool = false, done: @escaping () -> Void = {}) async {
        guard let client else { return }
        do {
            let result = try await client.blocklistRelease(body)
            let searching = result.searchDispatched == true
            let message: String
            if result.fileDeleted == true {
                message = searching ? "Blocklisted, deleted the file, and searching for a replacement" : "Blocklisted and deleted the file"
            } else if result.created {
                message = searching ? "Blocklisted — searching for a replacement" : "Release blocklisted"
            } else {
                message = searching ? "Already blocklisted — searching for a replacement" : "Already blocklisted"
            }
            let tone: ActToaster.Tone = result.created || searching ? .success : .warning
            if offerUndo, result.created, let id = result.entry?.id {
                toaster.show(message, tone: tone, undo: {
                    Task {
                        do {
                            try await client.deleteBlocklistEntry(id: id)
                            toaster.show("Blocklist cleared", tone: .success)
                            done()
                        } catch { toaster.error(error) }
                    }
                })
            } else {
                toaster.show(message, tone: tone)
            }
            done()
        } catch let error as APIError where error.status == 422 || error.status == 404 {
            toaster.show(error.serverDetail ?? "Couldn't blocklist this release — try again", tone: .warning)
        } catch {
            toaster.show("Couldn't blocklist this release — try again", tone: .error)
        }
    }

    static func search(_ client: APIClient?, _ toaster: ActToaster, itemId: Int, editionId: Int? = nil,
                       episodeId: Int? = nil, message: String) async {
        guard let client else { return }
        do {
            try await client.runSearch(itemId: itemId, editionId: editionId, episodeId: episodeId)
            toaster.show(message)
        } catch {
            toaster.error(error)
        }
    }

    static func copy(_ text: String?, _ toaster: ActToaster) {
        guard let text, !text.isEmpty else { return }
        UIPasteboard.general.string = text
        toaster.show("Release name copied")
    }
}
