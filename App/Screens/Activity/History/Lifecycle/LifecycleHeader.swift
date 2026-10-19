import SwiftUI
import FusionhaKit

/// The lifecycle sheet's header (web `LifecyclePanel` head + acts): poster,
/// title, episode code, tier chip and "LIFECYCLE", then Open in library,
/// Re-grab, Blocklist and Search again for the version on screen.
struct LifecycleHeader: View {
    let story: HistoryStory
    let tier: QualityTier?
    let versionId: Int?
    let episodeId: Int?
    let onChanged: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.dismiss) private var dismiss
    @State private var regrabbing = false
    @State private var blocking = false
    @State private var blocklistDialog = false

    private var target: BlocklistTarget? { story.actionEntry.blocklistTarget }
    private var grabbed: HistoryEntry? { story.events.first { $0.eventType == "GRABBED" } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ActPoster(url: story.posterUrl, title: story.title, size: .lg)
                VStack(alignment: .leading, spacing: 6) {
                    Text(story.title).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.txt)
                        .fixedSize(horizontal: false, vertical: true)
                    ActFlow(spacing: 6, lineSpacing: 4) {
                        if let code = HistoryLifecycleModel.episodeCode(story.episodeLabel) {
                            Text(code).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(Theme.mut)
                        }
                        if let tier { ActTierChip(tier: tier, edition: story.edition) }
                        Text("LIFECYCLE").font(.system(size: 11, weight: .bold)).tracking(0.8).foregroundStyle(Theme.dim)
                    }
                }
            }
            actions
        }
        .sheet(isPresented: $blocklistDialog) {
            BlocklistReleaseDialog(release: story.releaseTitle ?? story.title,
                                   keepsCurrentFile: target?.keepsCurrentFile == true) { search, deleteFile in
                blocklistDialog = false
                Task { await blocklist(search: search, deleteFile: deleteFile) }
            } onCancel: { blocklistDialog = false }
        }
    }

    private var actions: some View {
        HStack(spacing: 4) {
            if let id = story.mediaItemId {
                ActIconButton(systemImage: "arrow.up.right.square", label: "Open \(story.title) in library", tint: Theme.accentText) {
                    dismiss()
                    model.open(id)
                }
            }
            if let grabbed {
                ActIconButton(systemImage: "arrow.clockwise", label: "Re-grab this release", busy: regrabbing) {
                    Task {
                        regrabbing = true
                        await ActActions.regrab(model.client, toaster, historyId: grabbed.id, done: onChanged)
                        regrabbing = false
                    }
                }
            }
            if story.type.actions.blocklist {
                ActIconButton(systemImage: "nosign", label: "Blocklist this release", busy: blocking) { blocklistDialog = true }
                    .disabled(target == nil)
                    .opacity(target == nil ? 0.4 : 1)
                    .accessibilityHint(target == nil ? "This event carries no release to blocklist" : "")
            }
            ActIconButton(systemImage: "magnifyingglass", label: "Search again for \(story.title)", tint: Theme.indigo) {
                guard let id = story.mediaItemId else { return }
                Task { await ActActions.search(model.client, toaster, itemId: id, editionId: versionId, episodeId: episodeId,
                                               message: "Searching again for \(story.title)") }
            }
        }
    }

    private func blocklist(search: Bool, deleteFile: Bool) async {
        guard let target else { return }
        blocking = true
        await ActActions.blocklist(model.client, toaster, target.body(search: search, deleteFile: deleteFile), done: onChanged)
        blocking = false
    }
}
