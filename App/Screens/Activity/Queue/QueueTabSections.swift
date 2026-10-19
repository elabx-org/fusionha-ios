import SwiftUI
import FusionhaKit

// The Queue tab's sections (web `QueueCardGroups.tsx`): Needs you · Importing ·
// In progress · Downloading · Failed as cards, then Up next and Just finished.

extension ActivityQueueTab {
    @ViewBuilder
    var sections: some View {
        let items = store.items
        let routed = Dictionary(grouping: items, by: QueueSection.of)
        let cards = QueueSection.cardSections.compactMap { key -> (QueueSection, [QueueLogic.Entry])? in
            let list = routed[key] ?? []
            return list.isEmpty ? nil : (key, QueueLogic.entries(list, section: key, telemetry: store.telemetry))
        }
        let upNext = routed[.upnext] ?? []
        let finished = self.finished
        let first = cards.first?.0.label ?? (upNext.isEmpty ? "Just finished" : "Up next")
        Group {
            ForEach(cards, id: \.0) { key, entries in
                section(key.label, entries.reduce(0) { $0 + $1.downloadCount }, key.hint ?? "", first: first,
                        trailing: key == .needs ? reviewAll(items) : nil) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        card(entry)
                            .queueFlash(entry.contains(focusId), reduce: reduce)
                            .id(entry.id)
                            .actReveal(index).actRowTransition(reduce)
                    }
                }
            }
            if !upNext.isEmpty { upNextSection(upNext, first: first) }
            if !finished.rows.isEmpty { finishedSection(finished, first: first) }
        }
    }

    @ViewBuilder
    private func upNextSection(_ upNext: [QueueItem], first: String) -> some View {
        let onDeck = upNext[0]
        let rest = Array(upNext.dropFirst())
        let visible = upNextOpen ? rest : Array(rest.prefix(4))
        section("Up next", upNext.count, "next to grab", first: first) {
            selectable(onDeck) { OnDeckCard(item: onDeck, actions: actions(for: onDeck)) }
                .queueFlash(focusId == onDeck.id, reduce: reduce)
                .id(QueueFocus.upNextId(onDeck.id))
                .actReveal(0)
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, item in
                selectable(item, opensTitle: false) {
                    CompactUpNextRow(item: item, position: index + 2, actions: actions(for: item),
                                     expanded: upNextOpenId == item.id,
                                     toggle: { upNextOpenId = upNextOpenId == item.id ? nil : item.id })
                }
                .queueFlash(focusId == item.id, reduce: reduce)
                .id(QueueFocus.upNextId(item.id))
                .actReveal(index + 1, stagger: 0.03).actRowTransition(reduce)
            }
            if rest.count > visible.count {
                Button("+ \(rest.count - visible.count) more queued") { upNextOpen = true }
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.mut)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func finishedSection(_ finished: (rows: [QueueLogic.Finished], overflow: Int), first: String) -> some View {
        section("Just finished", finished.rows.count, "clears to History in ~20s", first: first) {
            ForEach(Array(finished.rows.enumerated()), id: \.element.id) { index, entry in
                JustFinishedRow(entry: entry).actReveal(index).actRowTransition(reduce)
            }
            if finished.overflow > 0 {
                Button("+\(finished.overflow) more · view in History") { chrome.tab = .history }
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.accentText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(.plain)
            }
        }
    }

    /// One card: a held or other single download, a 4K + HD pair, or a group.
    @ViewBuilder
    private func card(_ entry: QueueLogic.Entry) -> some View {
        switch entry {
        case .solo(let item, _):
            if item.cockpitState == .held {
                selectable(item) { QueueHeldCard(item: item, actions: actions(for: item)) }
            } else {
                selectable(item) {
                    QueueStateCard(item: item, telemetry: store.telemetry[item.id], actions: actions(for: item))
                }
            }
        case .group(let group, _) where group.isPair:
            QueuePairCard(group: group, telemetry: store.telemetry, selecting: selecting, selected: $selected,
                          actionsFor: { actions(for: $0) })
        case .group(let group, let eta):
            QueueGroupCard(group: group, telemetry: store.telemetry, eta: eta,
                           selecting: selecting, selected: $selected, focusId: focusId,
                           actionsFor: { actions(for: $0) },
                           removeAll: { items, deleteData, blocklist in
                               Task { await removeAll(items, deleteData: deleteData, blocklist: blocklist) }
                           },
                           pick: { selecting = true })
        }
    }

    /// Needs you's "Review all N": an outline capsule, right-aligned (0.4.198).
    private func reviewAll(_ items: [QueueItem]) -> AnyView? {
        let held = items.filter { $0.cockpitState == .held }.map(\.id)
        guard held.count > 1 else { return nil }
        return AnyView(
            Button("Review all \(held.count)") { router.manualImport(rescue: held) }
                .buttonStyle(ActButtonStyle(kind: .subtle))
                .accessibilityLabel("Review all \(held.count) in Manual Import")
        )
    }

    /// A section as flat children: its header, then each card (10pt apart; sections 24pt apart).
    @ViewBuilder
    private func section<C: View>(_ title: String, _ count: Int, _ hint: String, first: String,
                                  trailing: AnyView? = nil, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                ActSection(title: title, count: count)
                if let trailing { trailing }
            }
            if !hint.isEmpty {
                Text(hint).font(.system(size: 13)).foregroundStyle(Theme.dim)
            }
        }
        .padding(.top, title == first ? 0 : 24)
        Group { content() }.padding(.top, 10)
    }

    /// Select mode puts a checkbox before the card; otherwise a tap opens the title.
    @ViewBuilder
    private func selectable<C: View>(_ item: QueueItem, opensTitle: Bool = true, @ViewBuilder _ card: () -> C) -> some View {
        if selecting {
            HStack(alignment: .center, spacing: 10) {
                ActCheckbox(checked: selected.contains(item.id))
                card().allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if selected.contains(item.id) { selected.remove(item.id) } else { selected.insert(item.id) }
            }
            .actSelected(selected.contains(item.id))
        } else if opensTitle {
            card()
                .contentShape(Rectangle())
                .onTapGesture { model.open(item.mediaItemId) }
        } else {
            card()
        }
    }
}
