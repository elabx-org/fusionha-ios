import SwiftUI
import FusionhaKit

/// The queue with nothing in it (mock queue `clear`, W1): "All clear" with
/// the last import, Today | 7 days, the readiness tiles, the download
/// clients, Needs attention (phone only: the open Duo shows it on the right
/// page), Coming up next and Recently finished. v1's idle feed supplies it.
struct V2QueueIdleView: View {
    let feed: QueueIdleFeed
    let lastImport: QueuePipeline.LastImport?
    /// The open Duo's right page carries Needs attention.
    var attentionOnRight = false
    let openHistory: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page
    @State private var week = false
    @State private var showsClients = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            hero
            V2IdleTiles(summary: feed.summary, week: week)
            clients
            if !attentionOnRight, !V2LibraryAttention.items(model.library).isEmpty {
                V2NeedsAttentionRow(items: V2LibraryAttention.items(model.library), held: []) { model.tab = .library }
            }
            V2QueueUpNextModule(queued: [], tasks: feed.summary?.tasks, row: { _ in EmptyView() })
            recent
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.onFill(hex: Theme.palette.done))
                .frame(width: 54, height: 54)
                .background(Theme.done, in: Circle())
                .accessibilityHidden(true)
            Text("All clear").font(.title2.weight(.bold)).foregroundStyle(page?.ink ?? Theme.txt)
            if let line = QueuePipelineModel.lastImportLine(lastImport) {
                Text("Nothing downloading. \(line)")
                    .font(.footnote)
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .multilineTextAlignment(.center)
            }
            Picker("Range", selection: $week) {
                Text("Today").tag(false)
                Text("7 days").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    @ViewBuilder private var clients: some View {
        if let summary = feed.summary {
            DisclosureGroup(isExpanded: $showsClients) {
                ForEach(summary.clients.items) { client in
                    HStack {
                        Text(client.name).foregroundStyle(page?.ink ?? Theme.txt)
                        Spacer()
                        Text(client.enabled ? client.protocol.uppercased() : "Off")
                            .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    }
                    .font(.system(size: 13.5))
                    .padding(.top, 8)
                }
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(page?.ink ?? Theme.txt)
                        .frame(width: 30, height: 30)
                        .background((page?.ink ?? Theme.txt).opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Download clients · \(summary.clients.enabled) ready")
                            .font(.system(size: 14.5, weight: .semibold)).foregroundStyle(page?.ink ?? Theme.txt)
                        Text(summary.clients.items.map(\.name).joined(separator: ", "))
                            .font(.system(size: 12.5)).foregroundStyle(page?.inkMuted ?? Theme.mut).lineLimit(1)
                    }
                }
            }
            .tint(page?.inkMuted ?? Theme.mut)
            .padding(14)
            .background { ModuleSurface() }
        }
    }

    @ViewBuilder private var recent: some View {
        let rows = IdleRecent.derive(feed.imports ?? [], limit: IdleRecent.narrowLimit)
        if !rows.isEmpty {
            WidgetModule(caption: "Recently finished", systemImage: "checkmark") {
                Button("History", action: openHistory)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accentText)
                    .buttonStyle(.plain)
            } content: {
                ForEach(rows) { V2RecentRow(row: $0) }
            }
        }
    }
}

/// One finished import: poster, title, what landed, its badge and time.
struct V2RecentRow: View {
    let row: FinishedRow
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page

    var body: some View {
        Button { if let id = row.itemId { model.open(id) } } label: {
            HStack(spacing: 11) {
                PosterImage(url: TMDBImage.resized(row.posterUrl, to: "w185"), size: CGSize(width: 30, height: 45))
                    .frame(width: 30, height: 45)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.title).font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(page?.ink ?? Theme.txt).lineLimit(1)
                    Text([row.label, row.quality, row.extra].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.system(size: 12.5)).foregroundStyle(page?.inkMuted ?? Theme.mut).lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    if let tier = row.tier { EditionBadge(tier: tier, state: .onDisk, showsCount: false) }
                    Text(V2QueueTime.clock(row.at) ?? "")
                        .font(.caption.monospacedDigit()).foregroundStyle(page?.inkMuted ?? Theme.mut)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

/// Library titles that need the owner (files missing or unreadable, dead
/// links): the idle page's Needs attention, from the loaded library.
enum V2LibraryAttention {
    static func items(_ library: [MediaItem]) -> [MediaItem] {
        library.filter { $0.hasAttention == true || $0.editions.contains { $0.attention == true } }
    }
}
