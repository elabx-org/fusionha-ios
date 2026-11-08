import SwiftUI
import FusionhaKit

/// Every indexer as a row, grouped by search priority (mock `groups`): the
/// order fusionha queries them in, the first group "searched first" and
/// the last "last resort". Each group is one W1 card; rows keep the chosen
/// sort inside their group. Tapping a row opens its detail.
struct V2IndexerGroups: View {
    let rows: [IndexerMetric]
    let sortLabel: String
    let colorFor: (Int) -> Color
    let model: V2IndexersModel
    var selected: Int?
    /// The open Duo's list beside the detail: chevrons instead of switches.
    var chevrons = false
    var roomy = false
    let open: (Int) -> Void
    let onToggle: (SearchIndexerInfo, Bool) -> Void

    private struct PriorityGroup: Identifiable {
        let priority: Int
        let rows: [IndexerMetric]
        var id: Int { priority }
    }

    private var groups: [PriorityGroup] {
        let byPriority = Dictionary(grouping: rows) { $0.indexer.priority }
        return byPriority.keys.sorted().map { PriorityGroup(priority: $0, rows: byPriority[$0] ?? []) }
    }

    var body: some View {
        let all = groups
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(all.enumerated()), id: \.element.id) { index, group in
                V2SettingsGroupHeader(title: title(group.priority, index: index, count: all.count),
                                      trailing: index == 0 ? sortLabel : nil)
                card(group.rows)
            }
        }
    }

    private func title(_ priority: Int, index: Int, count: Int) -> String {
        if count > 1 && index == 0 { return "Priority \(priority) · searched first" }
        if count > 1 && index == count - 1 { return "Priority \(priority) · last resort" }
        return "Priority \(priority)"
    }

    private func card(_ list: [IndexerMetric]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(list.enumerated()), id: \.element.id) { index, metric in
                V2IndexerRow(metric: metric, color: colorFor(metric.id), result: model.results[metric.id],
                             testing: model.testing.contains(metric.id), selected: selected == metric.id,
                             chevron: chevrons, roomy: roomy,
                             onToggle: { onToggle(metric.indexer, $0) },
                             open: { open(metric.id) })
                .overlay(alignment: .top) {
                    if index > 0 { V2SettingsHairline(leading: 64) }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: ModuleMetrics.radius, style: .continuous))
        .background { ModuleSurface() }
    }
}
