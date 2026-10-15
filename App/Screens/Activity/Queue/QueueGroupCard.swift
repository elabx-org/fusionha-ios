import SwiftUI
import FusionhaKit

// MARK: - Group card (several downloads of one title)

struct QueueGroupCard: View {
    let group: QueueLogic.Group
    let telemetry: [Int: QueueTelemetry]
    let eta: Double?
    let soonest: Bool
    let selecting: Bool
    @Binding var selected: Set<Int>
    let actionsFor: (QueueItem) -> QueueRowActions
    let removeMany: (_ ids: [Int], _ blocklist: Bool) -> Void
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

    /// A pair always shows its lanes; a group remembers being opened.
    private var isOpen: Bool { group.isPair || (groupOpen ?? QueueGroupMemory.open.contains(group.id)) }

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
        ActGroupCard(wash: QueueGroupSummary(group: group).heldIds.isEmpty ? Theme.grab : Theme.stuck, base: Theme.panel,
                     defaultOpen: group.isPair || isOpen,
                     onToggle: { open in groupOpen = open; QueueGroupMemory.set(group.id, open: open) }) {
            ActPoster(url: lead.posterUrl, title: lead.title, size: .md)
                .onTapGesture { model.open(group.mediaItemId) }
        } title: {
            VStack(alignment: .leading, spacing: 8) {
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
            HStack(spacing: 14) {
                // The group's Manual Import, full width (web `groupAction`).
                if let label = QueueGroupSummary(group: group).reviewLabel {
                    Button {
                        router.manualImport(rescue: QueueGroupSummary(group: group).heldIds)
                    } label: {
                        Label(label, systemImage: "square.and.arrow.down").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ActButtonStyle(kind: .primary, small: false))
                }
                // Size is in the header's count line; only live transfer facts here.
                if counts.dl > 0 {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(ActFmt.rate(shownRate)).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(Theme.grab)
                            .contentTransition(.opacity)
                            .animation(reduce ? nil : .easeOut(duration: 0.2), value: shownRate > 0)
                        Text("speed").font(.system(size: 9.5, weight: .bold)).foregroundStyle(Theme.dim)
                    }
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(ActFmt.etaShort(eta)).font(.system(size: 13, weight: .bold).monospacedDigit()).foregroundStyle(Theme.txt)
                        Text("NEXT DONE").font(.system(size: 9.5, weight: .bold)).foregroundStyle(Theme.dim)
                    }
                }
                removeMenu(downloads: downloads, seasons: seasons, title: lead.title)
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
        .overlay {
            if soonest { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.grab.opacity(0.45)) }
        }
        .task(id: rate) {
            if rate > 0 { shownRate = rate; return }
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled { shownRate = 0 }
        }
    }

    /// The group's remove choices behind ⋯ (all, per season, with blocklist, pick).
    private func removeMenu(downloads: [QueueItem], seasons: [Int?: [QueueItem]], title: String) -> some View {
        ActMoreMenu(label: "Remove downloads for \(title)") {
            Button("Remove all (\(downloads.count))", systemImage: "trash") { removeMany(downloads.map(\.id), false) }
            if seasons.keys.compactMap({ $0 }).count >= 2 {
                ForEach(seasons.keys.compactMap { $0 }.sorted(), id: \.self) { s in
                    Button("Remove Season \(s) (\(seasons[s]?.count ?? 0))") { removeMany((seasons[s] ?? []).map(\.id), false) }
                }
            }
            Button("Remove + blocklist all", systemImage: "nosign", role: .destructive) { removeMany(downloads.map(\.id), true) }
            Divider()
            Button("Pick downloads…", systemImage: "checkmark.circle", action: pick)
        }
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
            QueueHeldCard(item: item, actions: actionsFor(item), nested: true, pairLane: group.isPair)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
        } else if selecting {
            compactRow(item)
        } else {
            // The same parts as a single card, without the poster and title.
            QueueStateCard(item: item, telemetry: telemetry[item.id], actions: actionsFor(item), nested: true, pairLane: group.isPair)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
        }
    }

    private func compactRow(_ item: QueueItem) -> some View {
        let state = item.cockpitState
        let stripe: Color = state == .stalled ? Theme.miss : (state == .queued ? Theme.dim : (state == .held ? Theme.stuck : Theme.grab))
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
        .overlay(alignment: .leading) {
            Capsule().fill(stripe).frame(width: 3).padding(.vertical, 8).offset(x: 5)
        }
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
