import SwiftUI
import FusionhaKit

/// One blocked release (mock activity-log.js `rr`): what it is, the indexer,
/// size and time, the reason in plain words, and Unblock and Search again
/// as round glass buttons (a check in select mode). Press and hold, or
/// "Details & reason", shows the raw reason, its formats, every collapsed
/// copy and the GUID (v1's row details). A collapsed ×N row acts on every copy.
struct V2BlocklistReleaseRow: View {
    let release: BlocklistGrouping.Release
    /// Under a title card (no poster, no title).
    var nested = true
    let showReasons: Bool
    let selecting: Bool
    let checked: Bool
    let unblock: (_ entries: [BlocklistEntry], _ search: Bool) -> Void
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.pagePalette) private var page
    @Environment(\.motionEnabled) private var motion
    @State private var expanded = false

    private var entry: BlocklistEntry { release.lead }
    private var category: BlocklistCategory { BlocklistCategory(reason: entry.reason) }
    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                if selecting { V2SelectCheck(on: checked).padding(.top, 2) }
                if !nested { V2ScopeThumb(url: entry.posterUrl, width: 34) }
                lines.frame(maxWidth: .infinity, alignment: .leading)
                if !selecting { buttons }
            }
            if expanded || (showReasons && entry.reason != nil) {
                V2BlocklistDetails(release: release, raw: expanded) { copy in unblock([copy], false) }
                    .padding(.leading, selecting ? 34 : 0)
                    .transition(.opacity)
            }
        }
        .contextMenu { if !selecting { menu } }
    }

    private var lines: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !nested, let title = entry.itemTitle {
                Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(ink).lineLimit(1)
            }
            Text(headline).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(ink).lineLimit(1)
            Text(meta).font(.system(size: 12)).foregroundStyle(muted).lineLimit(1)
            Text(reason).font(.system(size: 12, weight: .semibold)).foregroundStyle(reasonInk)
                .lineLimit(2).padding(.top, 2)
        }
    }

    /// "S1 E1 · Pilot · FLUX WEB-DL 1080p" (×N when copies collapse).
    private var headline: String {
        let name = entry.sourceTitle ?? entry.title
        let base = [entry.episodeLabel, name].compactMap { $0 }.joined(separator: " · ")
        return release.count > 1 ? "\(base) ×\(release.count)" : base
    }

    private var meta: String {
        [entry.quality.map { ActFmt.quality($0) }, entry.indexer, ActFmt.protocolLabel(entry.protocol),
         entry.size.map { ActFmt.bytes($0) }, ActFmt.relative(entry.createdAt)]
            .compactMap { $0 }.joined(separator: " · ")
    }

    private var reason: String {
        guard let raw = entry.reason else { return category.label }
        let fail = FailureCopy.format(raw, context: .blocklist)
        return category == .recoverable ? "\(fail.title) · can retry" : fail.title
    }

    private var reasonInk: Color {
        switch category {
        case .permanent: return Theme.dangerText
        case .manual: return muted
        case .recoverable: return ink
        }
    }

    private var buttons: some View {
        HStack(spacing: 6) {
            V2RoundIconButton(systemImage: "arrow.uturn.backward", label: "Remove from blocklist", size: 32) {
                unblock(release.entries, false)
            }
            if entry.mediaItemId != nil {
                V2RoundIconButton(systemImage: "magnifyingglass", label: "Search again", size: 32) { searchAgain() }
            }
        }
    }

    @ViewBuilder
    private var menu: some View {
        Button(category.primary.label, systemImage: category.primary.icon) {
            unblock(release.entries, category == .recoverable)
        }
        if entry.mediaItemId != nil {
            Button("Search again", systemImage: "magnifyingglass") { searchAgain() }
        }
        Button(expanded ? "Hide details" : "Details & reason", systemImage: "info.circle") {
            withAnimation(motion ? .easeOut(duration: 0.2) : nil) { expanded.toggle() }
        }
        Button("Copy release name", systemImage: "doc.on.doc") { ActActions.copy(entry.sourceTitle ?? entry.title, toaster) }
        if let id = entry.mediaItemId {
            Button("Open title", systemImage: "arrow.up.right.square") { model.open(id) }
        }
    }

    private func searchAgain() {
        guard let item = entry.mediaItemId else { return }
        Task {
            await ActActions.search(model.client, toaster, itemId: item, editionId: entry.editionId,
                                    episodeId: entry.episodeId, message: "Searching again for \(entry.itemTitle ?? entry.title)")
        }
    }
}

/// A release's details: the reason in plain words, and with `raw` the exact
/// reason, its custom formats, each collapsed copy (removable alone) and the GUID.
struct V2BlocklistDetails: View {
    let release: BlocklistGrouping.Release
    let raw: Bool
    let removeCopy: (BlocklistEntry) -> Void
    @Environment(ActToaster.self) private var toaster
    @Environment(\.pagePalette) private var page

    var body: some View {
        let entry = release.lead
        let muted = page?.inkMuted ?? Theme.mut
        VStack(alignment: .leading, spacing: 6) {
            if let reason = entry.reason {
                let fail = FailureCopy.format(reason, context: .blocklist)
                Text(raw ? fail.raw : fail.detail).font(.system(size: 12)).foregroundStyle(muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if raw {
                if let formats = entry.formats, !formats.isEmpty {
                    Text(formats.joined(separator: " · ")).font(.system(size: 11.5)).foregroundStyle(muted)
                }
                if release.count > 1 {
                    ForEach(release.entries) { copy in
                        HStack(spacing: 8) {
                            Text([copy.indexer ?? copy.source ?? "—", ActFmt.relative(copy.createdAt)].joined(separator: " · "))
                                .font(.system(size: 11.5)).foregroundStyle(muted)
                            Spacer(minLength: 0)
                            Button("Remove", systemImage: "xmark") { removeCopy(copy) }
                                .labelStyle(.iconOnly)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(muted)
                                .accessibilityLabel("Remove copy \(copy.id) from blocklist")
                        }
                    }
                }
                if let guid = entry.guid {
                    Button {
                        UIPasteboard.general.string = guid
                        toaster.show("GUID copied")
                    } label: {
                        Label(guid, systemImage: "doc.on.doc").font(.system(size: 11)).foregroundStyle(muted)
                            .lineLimit(1).truncationMode(.middle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Copy GUID")
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((page?.ink ?? Theme.txt).opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
