import SwiftUI
import FusionhaKit

/// One History story as a row of the stories module (mock activity-log.js
/// `story`): poster, title with the version's ticket and the time, what it
/// is, the outcome in one line and its detail, the release chips, then the
/// events in brief and the actions (Lifecycle and ⋯; a failure gets
/// Blocklist and Search).
struct V2HistoryStoryCard: View {
    let story: HistoryStory
    /// The open Duo's list: no chip row (mock `lean`).
    var lean = false
    let openLifecycle: () -> Void
    let onChanged: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.pagePalette) private var page
    @State private var actions = V2StoryActions()

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 11) {
                V2ScopeThumb(url: story.posterUrl)
                VStack(alignment: .leading, spacing: 0) {
                    titleLine
                    Text(story.episodeLabel ?? "Movie").font(.system(size: 12.5)).foregroundStyle(muted).lineLimit(1)
                    outcome.padding(.top, 6)
                }
            }
            if !lean && !chips.isEmpty { chipRow.padding(.top, 8) }
            foot.padding(.top, 9)
        }
        .contextMenu { menuItems }
        .v2StoryActionSheets(actions, story: story, onChanged: onChanged)
    }

    private var titleLine: some View {
        HStack(alignment: .center, spacing: 7) {
            Text(story.title).font(.system(size: 15, weight: .bold)).foregroundStyle(ink).lineLimit(1)
            if let tier = story.tier {
                EditionBadge(tier: tier, state: V2StoryCopy.badge(story.type), showsCount: false)
            }
            Spacer(minLength: 4)
            Text(V2QueueTime.clock(story.time) ?? ActFmt.relative(story.time))
                .font(.caption.monospacedDigit()).foregroundStyle(muted)
        }
    }

    private var outcome: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: V2StoryCopy.glyph(story.type))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(story.type == .failed ? Theme.dangerText : ink)
                Text(V2StoryCopy.headline(story)).font(.system(size: 14, weight: .semibold)).foregroundStyle(ink)
            }
            if let detail = V2StoryCopy.detail(story) {
                Text(detail).font(.system(size: 12.5)).foregroundStyle(muted).lineLimit(2)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var chips: [String] {
        var out = story.chips.map(\.label)
        if let indexer = story.indexer { out.append(indexer) }
        return out
    }

    private var chipRow: some View {
        ActFlow(spacing: 5, lineSpacing: 5) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                Text(chip)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ink)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
    }

    private var foot: some View {
        HStack(spacing: 8) {
            Text(V2StoryCopy.events(story)).font(.system(size: 12)).foregroundStyle(muted).lineLimit(1)
            Spacer(minLength: 4)
            if story.type == .failed {
                blocklistMenu
                if story.mediaItemId != nil {
                    V2CapsuleButton(title: "Search", systemImage: "magnifyingglass") {
                        actions.searchAgain(story, client: model.client, toaster: toaster)
                    }
                }
            } else {
                if story.mediaItemId != nil {
                    V2CapsuleButton(title: "Lifecycle", systemImage: "clock", action: openLifecycle)
                }
                Menu { menuItems } label: {
                    Image(systemName: "ellipsis").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                        .frame(width: 32, height: 32).contentShape(Circle())
                }
                .glassEffect(.regular.interactive(), in: Circle())
                .accessibilityLabel("More for \(story.title)")
            }
        }
    }

    /// Tap: blocklist with a replacement search (Undo in the toast); the
    /// menu offers the dialog (delete the file, no search).
    private var blocklistMenu: some View {
        let target = story.actionEntry.blocklistTarget
        return Menu {
            Button("Blocklist and search", systemImage: "nosign") { quickBlocklist() }
            Button("Blocklist options…", systemImage: "slider.horizontal.3") { actions.blocklistDialog = true }
        } label: {
            HStack(spacing: 5) {
                if actions.blocking { ProgressView().controlSize(.mini) } else { Image(systemName: "nosign") }
                Text("Blocklist")
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
            }
            .font(.system(size: 13.5, weight: .semibold))
            .foregroundStyle(Theme.txt)
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .contentShape(Capsule())
        } primaryAction: {
            quickBlocklist()
        }
        .glassEffect(.regular.interactive(), in: Capsule())
        .disabled(target == nil)
        .opacity(target == nil ? 0.4 : 1)
        .accessibilityHint(target == nil ? "This event carries no release to blocklist" : "")
    }

    @ViewBuilder
    private var menuItems: some View {
        let kinds = story.type.actions
        if let id = story.mediaItemId {
            Button("Open title", systemImage: "arrow.up.right.square") { model.open(id) }
            Button("Lifecycle", systemImage: "clock", action: openLifecycle)
        }
        if V2StoryActions.grab(of: story) != nil {
            Button("Re-grab this release", systemImage: "arrow.uturn.down") {
                Task { await actions.regrab(story, override: false, client: model.client, toaster: toaster, done: onChanged) }
            }
        }
        if kinds.blocklist, story.actionEntry.blocklistTarget != nil {
            Button("Blocklist and search", systemImage: "nosign") { quickBlocklist() }
            Button("Blocklist options…", systemImage: "slider.horizontal.3") { actions.blocklistDialog = true }
        }
        if let id = story.mediaItemId {
            Button("Search again", systemImage: "magnifyingglass") { actions.searchAgain(story, client: model.client, toaster: toaster) }
            Button("Why this decision", systemImage: "list.bullet") { model.open(id, tab: .searches) }
        }
        if let release = story.releaseTitle {
            Button("Copy release name", systemImage: "doc.on.doc") { ActActions.copy(release, toaster) }
        }
    }

    private func quickBlocklist() {
        Task {
            await actions.blocklist(story, search: true, deleteFile: false, client: model.client, toaster: toaster,
                                    done: onChanged)
        }
    }
}
