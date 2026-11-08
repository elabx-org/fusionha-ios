import SwiftUI
import FusionhaKit

/// v2's History tab (mock browse-title.js `historyTab`): Timeline |
/// Lifecycle | Insights and the "All versions" filter (v1's
/// `DetailVersionMenu`, the page scope: a selected version card lands here
/// already filtered, All versions stays in the menu), then the timeline:
/// per day a label on the ground over one W1 card of `V2HistoryEventRow`s,
/// newest first (owner 2026-11-05: content on the art ground sits on a card,
/// like the version, season and Next up cards).
/// The view choice shares v1's stored key. Insights is `V2HistoryInsights`.
struct V2HistoryTab: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.pagePalette) private var page
    @Environment(\.detailReduceMotion) private var reduce
    let detail: ItemDetail
    @AppStorage("fusionha:history-view") private var viewRaw = V2HistoryMode.timeline.rawValue

    private var entries: [HistoryEntry] {
        let ids = detail.scopeEditionIds(store.scope)
        return (detail.history ?? [])
            .filter { entry in
                guard let ids, let id = entry.editionId else { return true }
                return ids.contains(id)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        let mode = V2HistoryMode(rawValue: viewRaw) ?? .timeline
        let shown = entries
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Picker("History view", selection: $viewRaw) {
                    ForEach(V2HistoryMode.allCases, id: \.self) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)
                Spacer(minLength: 8)
                if detail.editions.count > 1 { DetailVersionMenu(detail: detail) }
            }
            .v2FadesUnderTitleBar()
            if shown.isEmpty {
                Text("No history yet for this title.")
                    .font(.system(size: 14))
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .v2CardStyle(padding: 14, radius: 20)
            } else {
                switch mode {
                case .timeline: V2HistoryTimeline(detail: detail, entries: shown)
                case .lifecycle: V2HistoryLifecycle(detail: detail, entries: shown)
                case .insights: V2HistoryInsights(versions: store.scopedEditions, entries: shown)
                }
            }
        }
        .animation(reduce ? nil : .easeInOut(duration: 0.2), value: viewRaw)
    }
}

enum V2HistoryMode: String, CaseIterable {
    case timeline, lifecycle, insights
    var title: String { rawValue.capitalized }
}

/// The timeline: a day label ("Yesterday", "3 Nov") on the ground, then
/// that day's rows in one card, the spine and glyphs inside it.
struct V2HistoryTimeline: View {
    @Environment(\.pagePalette) private var page
    let detail: ItemDetail
    let entries: [HistoryEntry]
    @State private var limit = 40

    var body: some View {
        let items = V2HistoryItem.build(entries, detail: detail)
        let days = V2HistoryItem.days(Array(items.prefix(limit)))
        VStack(alignment: .leading, spacing: 8) {
            ForEach(days.indices, id: \.self) { i in
                Text(days[i].day)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, i == 0 ? 0 : 12)
                    .padding(.leading, 4)
                let rows = days[i].items
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { item in
                        V2HistoryEventRow(detail: detail, item: item, last: item.id == rows.last?.id)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .v2CardStyle(padding: 14, radius: 20)
            }
            if items.count > limit {
                Button("Show \(min(40, items.count - limit)) more") { limit += 40 }
                    .font(.system(size: 13.5, weight: .semibold))
                    .buttonStyle(.glass)
                    .foregroundStyle(page?.ink ?? Theme.txt)
                    .v2FadesUnderTitleBar()
            }
        }
    }
}
