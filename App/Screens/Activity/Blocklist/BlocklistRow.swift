import SwiftUI
import FusionhaKit

// MARK: - Release row

struct BlocklistRowView: View {
    let entry: BlocklistEntry
    let nested: Bool
    /// Every copy sharing title + release + reason (the lead first).
    let copies: [BlocklistEntry]
    let showReasons: Bool
    let selecting: Bool
    let checked: Bool
    let unblock: (_ search: Bool) -> Void
    /// Un-blocklists one copy of a ×N row.
    let removeCopy: (BlocklistEntry) -> Void
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.actReduceMotion) private var reduce
    @State private var expanded = false

    var body: some View {
        let cat = BlocklistCategory(reason: entry.reason)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                if selecting { ActCheckbox(checked: checked).padding(.top, 2) }
                if !nested { ActPoster(url: entry.posterUrl, title: entry.itemTitle ?? entry.title, size: .sm) }
                VStack(alignment: .leading, spacing: 5) {
                    ActFlow(spacing: 6, lineSpacing: 3) {
                        if !nested, let t = entry.itemTitle {
                            Text(t).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(1)
                        }
                        if let ep = entry.episodeLabel {
                            Text(ep).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.mut).lineLimit(1)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: cat.icon).font(.system(size: 11, weight: .bold))
                            Text(cat.label)
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(cat.color)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(cat.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                        if copies.count > 1 {
                            Text("×\(copies.count)").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Theme.mut)
                        }
                    }
                    if showReasons, let reason = entry.reason {
                        Text(FailureCopy.format(reason, context: .blocklist).detail).font(.system(size: 11)).foregroundStyle(Theme.mut)
                    } else {
                        Text(entry.sourceTitle ?? entry.title)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.mut)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    ActFlow(spacing: 6, lineSpacing: 3) {
                        if let q = entry.quality { ActQualityChip(quality: q) }
                        if let size = entry.size { ActMonoChip(text: ActFmt.bytes(size)) }
                        let meta = [entry.indexer, ActFmt.protocolLabel(entry.protocol)].compactMap { $0 }.joined(separator: " · ")
                        if !meta.isEmpty {
                            Text(meta).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.dim)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !selecting {
                    HStack(spacing: -10) {
                        ActIconButton(systemImage: cat.primary.icon, label: cat.primary.label, tint: Theme.indigo) {
                            unblock(cat == .recoverable)
                        }
                        ActMoreMenu {
                            Button(cat.primary.label, systemImage: cat.primary.icon) { unblock(cat == .recoverable) }
                            Divider()
                            if let item = entry.mediaItemId {
                                Button("Search again", systemImage: "magnifyingglass") {
                                    Task { await ActActions.search(model.client, toaster, itemId: item, editionId: entry.editionId,
                                                                   episodeId: entry.episodeId, message: "Searching again for \(entry.itemTitle ?? entry.title)") }
                                }
                            }
                            Button("Details & reason", systemImage: "info.circle") {
                                if reduce { expanded.toggle() } else { withAnimation(.easeOut(duration: 0.2)) { expanded.toggle() } }
                            }
                            Button("Copy release name", systemImage: "doc.on.doc") { ActActions.copy(entry.sourceTitle ?? entry.title, toaster) }
                        }
                    }
                    .padding(.horizontal, -8)
                    .padding(.top, -8)
                }
            }
            if expanded { details.transition(.opacity) }
        }
        .padding(.horizontal, nested ? 16 : 12)
        .padding(.vertical, nested ? 8 : 9)
        .background { if !nested { Color.clear } }
        .modifier(BlocklistWash(nested: nested, tone: cat.tone))
        .actSelected(checked, radius: nested ? 0 : 14)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let reason = entry.reason {
                let fail = FailureCopy.format(reason, context: .blocklist)
                Text(fail.detail).font(.system(size: 12)).foregroundStyle(Theme.txt)
                Text(fail.raw).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.mut)
                    .padding(6).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 6))
            }
            if let formats = entry.formats, !formats.isEmpty {
                ActFlow(spacing: 5, lineSpacing: 5) {
                    ForEach(formats, id: \.self) { f in
                        ActMonoChip(text: f, color: Theme.edition, border: Theme.edition.opacity(0.35))
                    }
                }
            }
            if copies.count > 1 { copiesList }
            if let guid = entry.guid {
                HStack(spacing: 6) {
                    Text(guid).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.dim).lineLimit(1).truncationMode(.middle)
                    Button {
                        UIPasteboard.general.string = guid
                        toaster.show("GUID copied")
                    } label: { Image(systemName: "doc.on.doc").font(.system(size: 11)).foregroundStyle(Theme.mut) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Copy GUID")
                }
            }
        }
    }
}

extension BlocklistRowView {
    /// Each collapsed copy with its own remove (web `blocklist-copies`).
    var copiesList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(copies) { copy in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(copy.sourceTitle ?? copy.title).font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.txt).lineLimit(1).truncationMode(.middle)
                        Text([copy.indexer ?? copy.source ?? "—", ActFmt.relative(copy.createdAt),
                              copy.size.map { ActFmt.bytes($0) }].compactMap { $0 }.joined(separator: " · "))
                            .font(.system(size: 11)).foregroundStyle(Theme.dim)
                    }
                    Spacer(minLength: 0)
                    Button { removeCopy(copy) } label: {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.mut)
                            .frame(width: 32, height: 32).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove copy \(copy.id) from blocklist")
                }
            }
        }
        .padding(8)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct BlocklistWash: ViewModifier {
    let nested: Bool
    let tone: StatusTone

    func body(content: Content) -> some View {
        if nested && Theme.isMono {
            content.background(MonoWash(token: tone.mono, color: tone.color, radius: 0))
        } else if nested {
            content.background(
                LinearGradient(stops: [.init(color: tone.color.opacity(0.10), location: 0), .init(color: tone.color.opacity(0), location: 0.42)],
                               startPoint: .leading, endPoint: .trailing))
        } else {
            content.actWash(tone)
        }
    }
}
