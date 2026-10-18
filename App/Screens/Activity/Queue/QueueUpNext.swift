import SwiftUI
import FusionhaKit

// MARK: - Up next

struct OnDeckCard: View {
    let item: QueueItem
    let actions: QueueRowActions

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("1").font(.system(size: 13, weight: .heavy, design: .monospaced)).foregroundStyle(Theme.dim).frame(width: 14)
            ActPoster(url: item.posterUrl, title: item.title, size: .sm)
            VStack(alignment: .leading, spacing: 5) {
                QueueHead(item: item, chip: item.phase != nil && item.phase != "queued"
                          ? (item.phaseMeta.label, item.phaseMeta.tone) : ("ON DECK", Theme.i2))
                ReleaseLine(text: item.releaseTitle)
                PhaseReadout(item: item, ghost: true)
                HStack {
                    Text((["Waiting to start", ActFmt.bytes(item.size), item.downloadClient ?? "Unknown client"] + [item.indexer].compactMap { $0 })
                        .joined(separator: " · "))
                        .font(.system(size: 11)).foregroundStyle(Theme.mut).lineLimit(2)
                    Spacer(minLength: 0)
                    ActIconButton(systemImage: "trash", label: "Remove from queue") { actions.remove(false) }
                        .padding(.trailing, -8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .actWash(Theme.dim)
    }
}

struct CompactUpNextRow: View {
    let item: QueueItem
    let position: Int
    let actions: QueueRowActions
    @State private var expanded = false
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("\(position)").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Theme.dim).frame(width: 18)
                ActPoster(url: item.posterUrl, title: item.title, size: .sm)
                VStack(alignment: .leading, spacing: 3) {
                    QueueHead(item: item, chip: ("QUEUED", Theme.mut))
                    Text([ActFmt.bytes(item.size), item.indexer].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 11)).foregroundStyle(Theme.mut)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    if reduce { expanded.toggle() } else { withAnimation(.easeOut(duration: 0.2)) { expanded.toggle() } }
                } label: {
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.dim)
                        .rotationEffect(.degrees(expanded ? 90 : 0)).frame(width: 30, height: 30).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(expanded ? "Collapse" : "Expand")
                ActIconButton(systemImage: "trash", label: "Remove from queue") { actions.remove(false) }
                    .padding(.horizontal, -8)
            }
            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    ReleaseLine(text: item.releaseTitle)
                    PhaseReadout(item: item, ghost: true)
                    Text((["Position \(position) in line", ActFmt.bytes(item.size), item.downloadClient ?? "Unknown client"] + [item.indexer].compactMap { $0 })
                        .joined(separator: " · "))
                        .font(.system(size: 11)).foregroundStyle(Theme.mut)
                }
                .padding(.leading, 28)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .actWash(Theme.dim)
    }
}

// MARK: - Just finished

struct JustFinishedRow: View {
    let entry: QueueLogic.Finished
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        let item = entry.item
        let failed = entry.failed
        let epLabel = entry.count > 1 ? entry.season.map { String(format: "S%02d", $0) } : item.episodeLabel
        let root = item.step
        let note: String = failed
            ? (item.terminalReason ?? "Import failed")
            : entry.count > 1
                ? "\(entry.count) \(entry.season != nil ? "episodes" : "files") imported\(root.map { " into \($0)" } ?? "")"
                : "Imported\(root.map { " into \($0)" } ?? " into your library") · added to your library"
        HStack(alignment: .top, spacing: 12) {
            ActPoster(url: item.posterUrl, title: item.title, size: .sm)
            VStack(alignment: .leading, spacing: 5) {
                ActFlow(spacing: 6, lineSpacing: 3) {
                    Text(item.title).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(1)
                    if let epLabel { Text(epLabel).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.mut) }
                    ActTierChip(tier: item.tier, edition: item.edition, multipleEditions: item.hasMultipleEditions == true)
                    Text(failed ? "Failed" : "Imported\(entry.count > 1 ? " ×\(entry.count)" : "")")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(failed ? Theme.danger : Theme.done)
                        .padding(.horizontal, 7).padding(.vertical, 1)
                        .background((failed ? Theme.danger : Theme.done).opacity(0.12), in: Capsule())
                }
                Text("via \(item.downloadClient ?? "decypharr")").font(.system(size: 11)).foregroundStyle(Theme.mut)
                Text(note).font(.system(size: 11.5)).foregroundStyle(failed ? Theme.danger : Theme.mut)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let left = max(0, QueueLogic.finishedWindow - context.date.timeIntervalSince(entry.finishedAt))
                    HStack(spacing: 8) {
                        Text(failed ? "Failed" : "Done").font(.system(size: 11, weight: .bold)).foregroundStyle(failed ? Theme.danger : Theme.done)
                        Text("clears in \(Int(left.rounded()))s").font(.system(size: 11).monospacedDigit()).foregroundStyle(Theme.dim)
                        // `queue-grace`: the draining bar.
                        GeometryReader { geo in
                            Capsule().fill((failed ? Theme.danger : Theme.done).opacity(0.5))
                                .frame(width: geo.size.width * CGFloat(left / QueueLogic.finishedWindow))
                                .animation(reduce ? nil : .linear(duration: 1), value: left)
                        }
                        .frame(height: 3)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if failed {
                ActIconButton(systemImage: "magnifyingglass", label: "Search again", tint: Theme.indigo) {
                    Task { await ActActions.search(model.client, toaster, itemId: item.mediaItemId, editionId: item.editionId,
                                                   message: "Searching again for \(item.title)") }
                }
            } else {
                ActIconButton(systemImage: "arrow.up.right.square", label: "Open in library") { model.open(item.mediaItemId) }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .actWash(failed ? Theme.danger : Theme.done)
        .contentShape(Rectangle())
        .onTapGesture { model.open(item.mediaItemId) }
    }
}
