import SwiftUI
import FusionhaKit

/// The Duo's trailing column (web `QueueDuoPane.tsx`, mock v4 "Duo · 669"):
/// the tapped card in full: "Open in library" and Close, the poster and title,
/// then the facts, source, meta, stage rail and reason, with the readout and
/// actions pinned to the foot. A 4K + HD pair shows one lane per version, each
/// with its own actions. Solid content on the panel colour, never glass.
struct QueueDuoPane: View {
    let open: QueueDuoOpen
    let telemetry: [Int: QueueTelemetry]
    let actionsFor: (QueueItem) -> QueueRowActions
    let close: () -> Void
    @Environment(AppModel.self) private var model
    @AccessibilityFocusState private var titleFocused: Bool

    var body: some View {
        let lead = open.lead
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    head(lead)
                    hero(lead)
                    content
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .scrollBounceBehavior(.basedOnSize)
            foot
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.panel)
        .overlay(alignment: .leading) { Rectangle().fill(Theme.line).frame(width: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(lead.title)
        .accessibilityAction(.escape, close)
        // A screen reader lands on the title when a card opens.
        .onAppear { titleFocused = true }
        .onChange(of: open.entry.id) { titleFocused = true }
    }

    private func head(_ lead: QueueItem) -> some View {
        HStack(spacing: 8) {
            Button("Open in library") { model.open(lead.mediaItemId) }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accentText)
                .frame(minHeight: 44)
                .buttonStyle(.plain)
            Spacer(minLength: 0)
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.mut)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close details")
            .padding(.trailing, -10)
        }
        .padding(.vertical, -6)
    }

    private func hero(_ lead: QueueItem) -> some View {
        HStack(alignment: .bottom, spacing: 14) {
            PosterImage(url: TMDBImage.resized(lead.posterUrl, to: "w342"))
                .frame(width: 92, height: 138)
                .shelfPoster(radius: 8)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(lead.title)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Theme.txt)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($titleFocused)
                if let subtitle = subtitle(lead) {
                    Text(subtitle).font(.system(size: 14)).foregroundStyle(Theme.mut)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func subtitle(_ lead: QueueItem) -> String? {
        if case .group(let group, _) = open.entry { return "\(group.downloads.count) versions" }
        return QueueCardText.subtitle(lead)
    }

    @ViewBuilder private var content: some View {
        switch open.entry {
        case .solo(let item, _) where item.cockpitState == .held:
            QueueHeldCard(item: item, actions: actionsFor(item), bare: true)
        case .solo(let item, _):
            QueueStateCard(item: item, telemetry: telemetry[item.id], actions: actionsFor(item), bare: true)
        case .group(let group, _):
            ForEach(group.downloads) { item in
                QueueStateCard(item: item, telemetry: telemetry[item.id], actions: actionsFor(item),
                               nested: true, pairLane: true)
            }
            Text("Each version runs and imports on its own. Removing one leaves the other running.")
                .font(.system(size: 13)).foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// A single download's readout and actions, pinned under the scroll. A
    /// held card keeps Review in its body; a pair's lanes carry their own.
    @ViewBuilder private var foot: some View {
        if case .solo(let item, _) = open.entry, item.cockpitState != .held {
            let mode = QueueCardMode(item)
            let actions = actionsFor(item)
            HStack(spacing: 8) {
                QueueStateReadout(item: item, mode: mode, telemetry: telemetry[item.id], search: actions.search)
                Spacer(minLength: 0)
                QueueCardActions(item: item, actions: actions, broken: mode.isBroken)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Theme.panel)
            .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        }
    }
}
