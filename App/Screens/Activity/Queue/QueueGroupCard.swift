import SwiftUI
import UIKit
import FusionhaKit

// MARK: - Group card (several downloads of one title)

struct QueueGroupCard: View {
    let group: QueueLogic.Group
    let telemetry: [Int: QueueTelemetry]
    let eta: Double?
    let selecting: Bool
    @Binding var selected: Set<Int>
    /// A deep link's download (`?focus=`): its group opens around it.
    var focusId: Int? = nil
    let actionsFor: (QueueItem) -> QueueRowActions
    /// Removes the downloads one by one, then one combined toast (`use-remove-all`).
    let removeAll: (_ items: [QueueItem], _ deleteData: Bool, _ blocklist: Bool) -> Void
    let pick: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(ActRouter.self) private var router
    @Environment(\.actReduceMotion) private var reduce
    /// The combined rate as shown: a drop to zero holds the last non-zero
    /// reading for two polls first, so a lone zero sample between two real ones
    /// never blinks the speed out (the web's `useHeldRate`).
    @State private var shownRate: Double = 0
    /// The one member row opened in place (the web's single expanded row).
    @State private var openId: Int?
    /// Collapsed by default; remembered for this run (`QueueGroupMemory`).
    @State private var groupOpen: Bool?
    /// "Remove all": the bulk remove sheet listing every download.
    @State private var confirmingRemoveAll = false

    private var hasFocus: Bool { focusId.map { id in group.downloads.contains { $0.id == id } } ?? false }

    /// A group remembers being opened; a deep link to a member opens it.
    private var isOpen: Bool { hasFocus || (groupOpen ?? QueueGroupMemory.open.contains(group.id)) }

    var body: some View {
        let downloads = group.downloads
        let lead = downloads[0]
        let size = downloads.reduce(0) { $0 + $1.size }
        let done = downloads.reduce(0) { $0 + $1.bytesDone }
        let pct = size > 0 ? Int((done / size * 100).rounded()) : 0
        let rate = downloads.reduce(0) { $0 + (telemetry[$1.id]?.bps ?? 0) }
        let counts = (dl: downloads.filter { [.downloading, .awaiting, .importing].contains($0.cockpitState) }.count,
                      held: downloads.filter { $0.cockpitState == .held }.count)
        let seasons = Dictionary(grouping: downloads) { season($0) }
        let isSeries = downloads.contains { $0.episodeLabel != nil }
        ActGroupCard(wash: QueueLogic.groupWash(downloads), base: Theme.panel,
                     defaultOpen: isOpen, chevronInRow: true,
                     onToggle: { open in groupOpen = open; QueueGroupMemory.set(group.id, open: open) }) {
            ActPoster(url: lead.posterUrl, title: lead.title, size: .md)
                .onTapGesture { model.open(group.mediaItemId) }
        } title: {
            VStack(alignment: .leading, spacing: 8) {
                if selecting { selectAll(downloads) }
                QueueGroupHeaderText(summary: QueueGroupSummary(group: group), open: isOpen,
                                     openTitle: { model.open(group.mediaItemId) })
                if counts.dl > 0 {
                    HStack(spacing: 8) {
                        ActProgressBar(fraction: Double(pct) / 100, shimmer: true)
                        Text("\(pct)% overall").font(.system(size: 11, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.mut).fixedSize()
                    }
                }
            }
        } trailing: {
            HStack(spacing: 0) {
                // The group's Manual Import fills the row; the icon slots match a
                // single card's, so every primary shares a right edge (0.4.198).
                let summary = QueueGroupSummary(group: group)
                if !summary.heldIds.isEmpty && !selecting {
                    Button {
                        router.manualImport(rescue: summary.heldIds)
                    } label: {
                        Label(summary.heldIds.count == downloads.count ? "Review all \(summary.heldIds.count)" : "Review \(summary.heldIds.count)",
                              systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ActButtonStyle(kind: .primary, small: false))
                    .accessibilityLabel(summary.reviewLabel ?? "Review in Manual Import")
                    .padding(.trailing, 6)
                } else {
                    Spacer(minLength: 0)
                }
                // Size is in the header's count line; only live transfer facts here.
                if counts.dl > 0 {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(ActFmt.rate(shownRate)).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(Theme.grab)
                            .contentTransition(.opacity)
                            .animation(reduce ? nil : .easeOut(duration: 0.2), value: shownRate > 0)
                        Text("speed").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.dim)
                    }
                    .padding(.trailing, 12)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(ActFmt.etaShort(eta)).font(.system(size: 13, weight: .bold).monospacedDigit()).foregroundStyle(Theme.txt)
                        Text("Next done").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.dim)
                    }
                    .padding(.trailing, 6)
                }
                QueueIconSlot(icon: "trash", label: "Remove all \(downloads.count) downloads", tint: Theme.danger) {
                    confirmingRemoveAll = true
                }
                moreMenu(downloads: downloads, seasons: seasons, lead: lead)
            }
            // Ahead of the card's leading spacer, so the button runs full width.
            .layoutPriority(1)
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                let keys = isSeries ? seasons.keys.sorted { ($0 ?? 0) < ($1 ?? 0) } : [nil]
                ForEach(keys, id: \.self) { key in
                    ForEach(isSeries ? (seasons[key] ?? []) : downloads) { item in
                        nestedRow(item)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        // Re-made when a deep link focuses a member, so the card opens around it.
        .id(hasFocus)
        .sheet(isPresented: $confirmingRemoveAll) {
            BulkRemoveDialog(count: downloads.count, fileCount: downloads.filter { $0.hasDownloadedFile == true }.count,
                             entries: removeEntries(downloads), defaultBlocklist: false, busy: false) { deleteFiles, blocklist in
                confirmingRemoveAll = false
                removeAll(downloads, deleteFiles, blocklist)
            } onCancel: { confirmingRemoveAll = false }
        }
        .task(id: rate) {
            if rate > 0 { shownRate = rate; return }
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled { shownRate = 0 }
        }
    }

    /// The group's ⋯ (0.4.198): open the title, copy the release names,
    /// remove one season, or pick downloads.
    private func moreMenu(downloads: [QueueItem], seasons: [Int?: [QueueItem]], lead: QueueItem) -> some View {
        ActMoreMenu(label: "More for \(lead.title)") {
            Button("Open title", systemImage: "rectangle.portrait.on.rectangle.portrait") { model.open(group.mediaItemId) }
            Button("Copy release names", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = downloads.compactMap(\.releaseTitle).joined(separator: "\n")
            }
            if seasons.keys.compactMap({ $0 }).count >= 2 {
                Divider()
                ForEach(seasons.keys.compactMap { $0 }.sorted(), id: \.self) { s in
                    Button("Remove Season \(s) (\(seasons[s]?.count ?? 0))") { removeAll(seasons[s] ?? [], false, false) }
                }
            }
            Divider()
            Button("Pick downloads…", systemImage: "checkmark.circle", action: pick)
        }
        .frame(width: 40, height: 44)
    }

    /// "Severance · S02E03" (or the release name) with its size, per download.
    private func removeEntries(_ downloads: [QueueItem]) -> [BulkRemoveEntry] {
        downloads.map { item in
            let label = QueueRemoveAllCopy.stripLabel(item.episodeLabel).map { "\(item.title) · \($0)" }
                ?? item.releaseTitle ?? item.title
            return BulkRemoveEntry(label: label, size: item.size)
        }
    }

    /// The header's "Select all N" checkbox (web `QueueGroupCard` RowCheck).
    private func selectAll(_ downloads: [QueueItem]) -> some View {
        let ids = Set(downloads.map(\.id))
        let all = ids.isSubset(of: selected)
        return Button {
            if all { selected.subtract(ids) } else { selected.formUnion(ids) }
        } label: {
            HStack(spacing: 8) {
                ActCheckbox(checked: all)
                Text("Select all \(downloads.count)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select all \(downloads.count) \(downloads[0].title) downloads")
    }

    private func season(_ item: QueueItem) -> Int? {
        guard let label = item.episodeLabel, let r = label.range(of: #"S(\d{1,3})"#, options: .regularExpression) else { return nil }
        return Int(label[r].dropFirst())
    }

    /// A member of the group. Held / stuck members get the attention card's
    /// nested variant (reason, why, Manual import, block); the rest are compact
    /// rows that open in place to show the release, client and actions.
    @ViewBuilder
    private func nestedRow(_ item: QueueItem) -> some View {
        let state = item.cockpitState
        if state == .held && !selecting {
            // The web's GroupRow: the single card's parts, no poster or title.
            QueueHeldCard(item: item, actions: actionsFor(item), nested: true)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
        } else if selecting {
            compactRow(item)
        } else {
            // The same parts as a single card, without the poster and title.
            QueueStateCard(item: item, telemetry: telemetry[item.id], actions: actionsFor(item), nested: true)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
        }
    }

    private func compactRow(_ item: QueueItem) -> some View {
        let state = item.cockpitState
        let wash = QueueLogic.wash(item)
        let open = openId == item.id && !selecting
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                if selecting { ActCheckbox(checked: selected.contains(item.id)) }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.episodeLabel ?? item.tier.chipLabel).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                        if item.episodeLabel != nil { ActTierChip(tier: item.tier, edition: item.edition, multipleEditions: item.hasMultipleEditions == true) }
                        Spacer(minLength: 0)
                        Text(state == .queued ? "queued" : (state == .stalled ? "stalled" : ActFmt.rate(telemetry[item.id]?.bps ?? 0)))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(state == .stalled ? Theme.miss : Theme.mut)
                        Text("\(item.pct)%").font(.system(size: 11, weight: .bold).monospacedDigit()).foregroundStyle(Theme.txt).frame(width: 36, alignment: .trailing)
                    }
                    ActProgressBar(fraction: Double(item.pct) / 100, height: 4, shimmer: state == .downloading)
                }
                if !selecting {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.mut)
                        .rotationEffect(.degrees(open ? 180 : 0))
                        .frame(width: 24)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if selecting {
                    if selected.contains(item.id) { selected.remove(item.id) } else { selected.insert(item.id) }
                } else {
                    withAnimation(reduce ? nil : .snappy(duration: 0.25)) { openId = open ? nil : item.id }
                }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(open ? "Hides the details" : "Shows the details")
            if open { memberDetails(item) }
        }
        .padding(.leading, 20)
        .padding(.trailing, 16)
        .padding(.vertical, 8)
        // The member's state as a wash, never a left bar.
        .actWash(wash, radius: 10, base: .clear, border: .clear)
    }

    /// The opened member: release, client · indexer · protocol · age, the next
    /// step, then Open title and the row's actions (search, remove, more).
    private func memberDetails(_ item: QueueItem) -> some View {
        let actions = actionsFor(item)
        return VStack(alignment: .leading, spacing: 6) {
            ReleaseLine(text: item.releaseTitle)
            QueueMetaLine(item: item)
            if let next = item.nextStep {
                Text(next).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.mut)
            }
            HStack {
                Button("Open title", systemImage: "arrow.up.right") { model.open(item.mediaItemId) }
                    .buttonStyle(ActButtonStyle(kind: .subtle))
                Spacer(minLength: 0)
                QueueActionsView(item: item, actions: actions,
                                 primary: QueuePrimary(icon: "magnifyingglass", label: "Search", run: actions.search),
                                 offerSearch: true)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}
