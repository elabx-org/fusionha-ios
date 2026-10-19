import SwiftUI
import FusionhaKit

/// A held download, as the web's v4 card (CardShell + HeldBody): poster,
/// title and episode; then "HD · 1.8 GB · grabbed 22h ago · RSS", the
/// release-fact chips, Usenet · indexer · client, the stage rail ending in
/// "Import held", the reason ("Smaller than its name says · would replace
/// your 4K FUZEER copy"), "Why it's held", and "Review in Manual Import"
/// beside the icon actions.
///
/// `nested`: a row inside a group card (web `GroupRow`): no poster, the
/// episode leads with the icon actions top-right, and the group header
/// carries the Manual Import button.
struct QueueHeldCard: View {
    let item: QueueItem
    let actions: QueueRowActions
    var nested = false
    /// A lane of a 4K + HD pair: the version leads, not the shared episode.
    var pairLane = false
    @Environment(AppModel.self) private var model
    @Environment(\.actReduceMotion) private var reduce
    @State private var showWhy = false
    @State private var blocking = false
    /// The group's mislabel evidence: gates the proof strip and the `block=1` link.
    @State private var evidence: ReleaseGroupEvidence?

    /// A proven fake from a named group, for someone who may block groups.
    private var blockableGroup: String? {
        guard HeldCopy.isProvenMislabel(item.heldDetail), let group = item.heldDetail?.releaseGroup,
              model.me?.can("integrations.manage") == true else { return nil }
        return group
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if nested { nestedHead } else { head }
            QueueCardMeta(item: item, showTier: !nested)
            QueueFactChips(item: item)
            QueueSourceLine(item: item)
            QueueStageRailView(model: QueueRail.held(item))
            if QueuePackSection.shows(item) { QueuePackSection(item: item) }
            reason
            if item.heldDetail != nil { whyToggle }
            if showWhy, let detail = item.heldDetail {
                HeldWhy(item: item, detail: detail, evidence: evidence, canBlockGroup: blockableGroup != nil,
                        onImportAnyway: actions.manualImport, onBlockGroup: { _ in blocking = true })
                    .transition(.opacity)
                    .task { await loadEvidence() }
            }
            if !nested {
                HStack(spacing: 6) {
                    Button(action: actions.manualImport) {
                        // "Review" on a phone; the full words stay for VoiceOver (0.4.198).
                        Label("Review", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ActButtonStyle(kind: .primary, small: false))
                    .accessibilityLabel("Review in Manual Import")
                    QueueCardActions(item: item, actions: actions)
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, nested ? 14 : 18)
        .actWash(QueueLogic.wash(item), radius: nested ? 12 : 16, base: nested ? Theme.panel.opacity(0.55) : Theme.card,
                 border: nested ? .clear : Theme.line)
        .task(id: model.pendingQueueFocus?.downloadId) { await consumeFocus() }
        .sheet(isPresented: $blocking) {
            if let group = blockableGroup {
                BlockReleaseGroupSheet(group: group, mediaItemId: item.mediaItemId, title: item.title,
                                       claimedResolution: item.heldDetail?.claimedResolution,
                                       probedSize: item.heldDetail?.probedResolution.map { "\($0.w)×\($0.h)" })
            }
        }
    }

    private var head: some View {
        HStack(alignment: .top, spacing: 14) {
            ActPoster(url: item.posterUrl, title: item.title, size: .md)
                .onTapGesture { model.open(item.mediaItemId) }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(2)
                    .onTapGesture { model.open(item.mediaItemId) }
                    .accessibilityAddTraits(.isButton)
                if let sub = QueueCardText.subtitle(item) {
                    Text(sub).font(.system(size: 15)).foregroundStyle(Theme.mut).lineLimit(2)
                }
            }
            .padding(.top, 6)
            Spacer(minLength: 0)
        }
    }

    private var nestedHead: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(pairLane ? QueueCardText.versionLabel(item) : (QueueCardText.subtitle(item) ?? item.releaseTitle ?? item.title))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.txt)
                .lineLimit(2)
            Spacer(minLength: 4)
            QueueCardActions(item: item, actions: actions)
                .padding(.trailing, -8)
        }
    }

    private var reason: some View {
        let r = QueueCardText.heldReason(item)
        return VStack(alignment: .leading, spacing: 4) {
            (Text(r.lead).fontWeight(.semibold).foregroundColor(Theme.txt)
             + Text(r.guard.map { " · \($0)" } ?? "").foregroundColor(Theme.mut))
                .font(.system(size: 15))
            // The server's full sentence, when no "Why it's held" panel explains it.
            if let text = r.text {
                Text(text).font(.system(size: 13.5)).foregroundStyle(Theme.mut)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var whyToggle: some View {
        Button {
            if reduce { showWhy.toggle() } else { withAnimation(.easeOut(duration: 0.16)) { showWhy.toggle() } }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .rotationEffect(.degrees(showWhy ? 180 : 0))
                Text(showWhy ? "Hide details" : "Why it's held")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.mut)
            .frame(minHeight: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// The block prompt shows only while the server says it is due.
    private func loadEvidence() async {
        guard evidence == nil, let group = blockableGroup, let client = model.client else { return }
        evidence = try? await client.releaseGroupEvidence(group: group, mediaItemId: item.mediaItemId)
    }

    /// A held-fake push links here with `block=1`: the dialog opens on this row
    /// only while the prompt is due; otherwise the row just focuses.
    private func consumeFocus() async {
        guard let focus = model.pendingQueueFocus, focus.downloadId == item.id else { return }
        model.pendingQueueFocus = nil
        guard focus.block, blockableGroup != nil else { return }
        await loadEvidence()
        if evidence?.prompt.shouldPrompt == true { blocking = true }
    }
}
