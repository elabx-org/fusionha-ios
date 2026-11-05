import SwiftUI
import FusionhaKit

/// A History story's actions, shared by its card and its lifecycle (v1's
/// `HistoryStoryRow` calls): Re-grab with the 409 "blocklisted" confirm,
/// Blocklist (one tap with a replacement search and Undo, or the dialog),
/// and Search again for the story's own episode.
@MainActor
@Observable
final class V2StoryActions {
    var blocklistDialog = false
    var regrabConflict = false
    var regrabbing = false
    var blocking = false

    static func grab(of story: HistoryStory) -> HistoryEntry? {
        story.events.first { $0.eventType == "GRABBED" }
    }

    func regrab(_ story: HistoryStory, override: Bool, client: APIClient?, toaster: ActToaster,
                done: @escaping () -> Void) async {
        guard let client else { return }
        regrabbing = true
        defer { regrabbing = false }
        do {
            let r = try await client.regrab(historyId: story.actionEntry.id, override: override)
            regrabConflict = false
            if r.grabbed {
                let indexer = r.indexerName ?? "the indexer"
                toaster.show(r.fromOriginalIndexer == false ? "Grabbed from \(indexer) (original unavailable)" : "Re-grabbed from \(indexer)",
                             tone: .success)
                done()
            } else {
                toaster.show(r.reason ?? "Nothing to re-grab", tone: .warning)
            }
        } catch let error as APIError where error.status == 409 && !override {
            regrabConflict = true
        } catch let error as APIError where error.status == 422 || error.status == 404 {
            toaster.show(error.serverDetail ?? "Couldn't re-grab this release — try again", tone: .warning)
        } catch {
            toaster.show("Couldn't re-grab this release — try again", tone: .error)
        }
    }

    func blocklist(_ story: HistoryStory, search: Bool, deleteFile: Bool, client: APIClient?, toaster: ActToaster,
                   done: @escaping () -> Void) async {
        guard let target = story.actionEntry.blocklistTarget else { return }
        blocking = true
        await ActActions.blocklist(client, toaster, target.body(search: search, deleteFile: deleteFile), done: done)
        blocking = false
    }

    func searchAgain(_ story: HistoryStory, client: APIClient?, toaster: ActToaster) {
        guard let id = story.mediaItemId else { return }
        Task {
            await ActActions.search(client, toaster, itemId: id, editionId: story.actionEntry.editionId,
                                    episodeId: story.actionEntry.episodeId,
                                    message: "Searching again for \(story.title)")
        }
    }
}

extension View {
    /// The blocklist dialog and the re-grab override confirm for a story.
    func v2StoryActionSheets(_ actions: V2StoryActions, story: HistoryStory, onChanged: @escaping () -> Void) -> some View {
        modifier(V2StoryActionSheets(actions: actions, story: story, onChanged: onChanged))
    }
}

private struct V2StoryActionSheets: ViewModifier {
    @Bindable var actions: V2StoryActions
    let story: HistoryStory
    let onChanged: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $actions.blocklistDialog) {
                BlocklistReleaseDialog(release: story.releaseTitle ?? story.title,
                                       keepsCurrentFile: story.actionEntry.blocklistTarget?.keepsCurrentFile == true) { search, deleteFile in
                    actions.blocklistDialog = false
                    Task {
                        await actions.blocklist(story, search: search, deleteFile: deleteFile, client: model.client,
                                                toaster: toaster, done: onChanged)
                    }
                } onCancel: { actions.blocklistDialog = false }
            }
            .sheet(isPresented: $actions.regrabConflict) {
                ActDialog(title: "Re-grab a blocklisted release?",
                          message: "\(story.releaseTitle ?? story.title) is blocklisted for this version. Re-grab it anyway? This clears the block first.",
                          confirmLabel: "Re-grab anyway", confirmKind: .primary, busy: actions.regrabbing,
                          onCancel: { actions.regrabConflict = false },
                          onConfirm: {
                              Task {
                                  await actions.regrab(story, override: true, client: model.client, toaster: toaster,
                                                       done: onChanged)
                              }
                          }) { EmptyView() }
            }
    }
}
