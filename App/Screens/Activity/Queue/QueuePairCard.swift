import SwiftUI
import FusionhaKit

/// The 4K + HD pair (web `PairCard.tsx`): one card for the title, one lane per
/// version, always open, each with its own facts, rail and actions. Removing
/// one leaves the other running, so there is no "Remove all".
struct QueuePairCard: View {
    let group: QueueLogic.Group
    let telemetry: [Int: QueueTelemetry]
    let selecting: Bool
    @Binding var selected: Set<Int>
    let actionsFor: (QueueItem) -> QueueRowActions
    @Environment(AppModel.self) private var model
    @Environment(\.queueCardOpener) private var opener

    var body: some View {
        let downloads = group.downloads
        let lead = downloads[0]
        VStack(alignment: .leading, spacing: 12) {
            header(lead, downloads: downloads)
            ForEach(downloads) { item in lane(item) }
            Text("Each version runs and imports on its own. Removing one leaves the other running.")
                .font(.system(size: 13)).foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .actWash(QueueWashStatus.working.tone, radius: 16, base: Theme.card)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(lead.title), \(downloads.count) versions")
    }

    private func header(_ lead: QueueItem, downloads: [QueueItem]) -> some View {
        let summary = QueueGroupSummary(group: group)
        let ids = Set(downloads.map(\.id))
        let all = ids.isSubset(of: selected)
        return HStack(alignment: .top, spacing: 12) {
            if selecting {
                Button {
                    if all { selected.subtract(ids) } else { selected.formUnion(ids) }
                } label: { ActCheckbox(checked: all).frame(width: 44, height: 44) }
                .buttonStyle(.plain)
                .accessibilityLabel("Select all \(downloads.count) \(lead.title) downloads")
                .padding(.horizontal, -12)
            }
            ActPoster(url: lead.posterUrl, title: lead.title, size: .md)
                .onTapGesture { model.openQueueCard(lead, opener: opener) }
            VStack(alignment: .leading, spacing: 4) {
                Text(lead.title).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(2)
                    .onTapGesture { model.openQueueCard(lead, opener: opener) }
                    .accessibilityAddTraits(.isButton)
                if let sub = QueueCardText.subtitle(lead) {
                    Text(sub).font(.system(size: 15)).foregroundStyle(Theme.mut).lineLimit(2)
                }
                Text("\(summary.versionLabel) · \(summary.countLine)")
                    .font(.system(size: 14).monospacedDigit()).foregroundStyle(Theme.mut)
            }
            .padding(.top, 4)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func lane(_ item: QueueItem) -> some View {
        let card = QueueStateCard(item: item, telemetry: telemetry[item.id], actions: actionsFor(item),
                                  nested: true, pairLane: true)
        if selecting {
            HStack(spacing: 8) {
                ActCheckbox(checked: selected.contains(item.id))
                card.allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if selected.contains(item.id) { selected.remove(item.id) } else { selected.insert(item.id) }
            }
            .actSelected(selected.contains(item.id), radius: 12)
        } else {
            card
        }
    }
}
