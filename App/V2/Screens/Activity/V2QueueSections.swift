import SwiftUI
import FusionhaKit

/// The live queue's modules (mock queue `rails`, W1): Needs you, Importing,
/// In progress, Downloading, Failed, then Up next (queued downloads and the
/// next scheduled runs) and Just finished. Each section is one W1 module,
/// its caption inside, its rows split by hairlines.
struct V2QueueSections: View {
    let store: QueueStore
    let summary: IdleSummary?
    let selecting: Bool
    @Binding var selected: Set<Int>
    /// The held download open on the right page (open Duo).
    let openHeld: Int?
    let review: (QueueItem) -> Void
    let reviewAll: ([Int]) -> Void
    let actions: V2QueueRowActions
    let openHistory: () -> Void
    /// The open Duo's overview column shows the scheduled runs (Up next),
    /// so the queue lists only its waiting downloads, as "Queued".
    var runsInOverview = false

    var body: some View {
        let items = store.items
        let routed = Dictionary(grouping: items, by: QueueSection.of)
        VStack(spacing: 14) {
            ForEach(QueueSection.cardSections, id: \.self) { section in
                if let list = routed[section], !list.isEmpty {
                    module(section, list)
                }
            }
            V2QueueUpNextModule(queued: routed[.upnext] ?? [], tasks: runsInOverview ? nil : summary?.tasks,
                                caption: runsInOverview ? "Queued" : "Up next",
                                row: { item in row(item, downloads: [item]) })
            V2JustFinishedModule(rows: QueueLogic.justFinished(store.justFinished), openHistory: openHistory)
        }
    }

    @ViewBuilder
    private func module(_ section: QueueSection, _ list: [QueueItem]) -> some View {
        let entries = QueueLogic.entries(list, section: section, telemetry: store.telemetry)
        let held = list.filter { $0.cockpitState == .held }.map(\.id)
        WidgetModule(caption: "\(section.label) · \(list.count)",
                     systemImage: section == .needs ? "pause.fill" : "arrow.down",
                     needsYou: section == .needs) {
            if section == .needs, held.count > 1, !selecting {
                Button("Resolve all") { reviewAll(held) }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accentText)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Review all \(held.count) in Manual Import")
            }
        } content: {
            ForEach(entries) { entry in
                switch entry {
                case .solo(let item, _): row(item, downloads: [item])
                case .group(let group, _): row(group.downloads[0], downloads: group.downloads)
                }
            }
        }
    }

    /// One row: a held summary, or a card with a lane per download. Select
    /// mode checks the row's downloads; otherwise a tap opens the decision
    /// (held) or the title.
    @ViewBuilder
    private func row(_ lead: QueueItem, downloads: [QueueItem]) -> some View {
        let ids = Set(downloads.map(\.id))
        let checked: Bool? = selecting ? ids.isSubset(of: selected) : nil
        Group {
            if lead.cockpitState == .held, downloads.count == 1 {
                HeldRowSummary(item: lead, selected: openHeld == lead.id, checked: checked) { review(lead) }
            } else {
                QueueCardV2(downloads: downloads, telemetry: store.telemetry, checked: checked)
            }
        }
        .id(lead.id)
        .onTapGesture { tap(lead, ids: ids) }
        .contextMenu { if !selecting { V2QueueRowMenu(item: lead, actions: actions) } }
    }

    private func tap(_ lead: QueueItem, ids: Set<Int>) {
        if selecting {
            if ids.isSubset(of: selected) { selected.subtract(ids) } else { selected.formUnion(ids) }
        } else if lead.cockpitState == .held {
            review(lead)
        } else {
            actions.openTitle(lead)
        }
    }
}
