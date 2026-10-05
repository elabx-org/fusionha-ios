import SwiftUI
import WidgetKit
import FusionhaKit

/// Library: titles and versions, the movies/series/anime kind bar, the
/// Complete / Downloading / Missing / Upcoming counts and 4K coverage.
struct WidgetLibraryPage: View {
    let summary: WidgetLibrarySummary?
    let large: Bool

    var body: some View {
        if let s = summary {
            VStack(alignment: .leading, spacing: large ? 10 : 6) {
                totals(s)
                WidgetKindBar(summary: s, showsLegend: large)
                statuses(s)
                WidgetCoverageMeter(summary: s)
            }
        } else {
            WidgetEmptyText("Library unavailable")
        }
    }

    private func totals(_ s: WidgetLibrarySummary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            total(s.titles, s.titles == 1 ? "title" : "titles")
            total(s.versions, s.versions == 1 ? "version" : "versions")
            Spacer(minLength: 0)
        }
    }

    private func total(_ value: Int, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text("\(value)").font(.system(size: large ? 20 : 16, weight: .bold).monospacedDigit())
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
        }
    }

    private func statuses(_ s: WidgetLibrarySummary) -> some View {
        let items: [(CardStatus, Int, String)] = [
            (.complete, s.complete, "Complete"), (.downloading, s.downloading, "Downloading"),
            (.missing, s.missing, "Missing"), (.upcoming, s.upcoming, "Upcoming"),
        ]
        return Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            if large {
                GridRow { ForEach(0..<2, id: \.self) { tile(items[$0]) } }
                GridRow { ForEach(2..<4, id: \.self) { tile(items[$0]) } }
            } else {
                GridRow { ForEach(0..<4, id: \.self) { tile(items[$0]) } }
            }
        }
    }

    private func tile(_ item: (CardStatus, Int, String)) -> some View {
        WidgetStatTile(value: "\(item.1)", label: item.2, color: item.0.color)
    }
}
