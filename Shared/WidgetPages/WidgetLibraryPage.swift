import SwiftUI
import WidgetKit
import FusionhaKit

/// Library, medium and large: the title count big, versions, the
/// movies/series/anime bar with its legend and a 4K coverage ring; large adds
/// the Complete / Downloading / Missing / Upcoming tiles.
struct WidgetLibraryPage: View {
    let summary: WidgetLibrarySummary?
    let large: Bool

    var body: some View {
        if let s = summary {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        WidgetNumber(value: "\(s.titles)", caption: s.totalsCaption, size: large ? 44 : 38)
                        WidgetKindBar(summary: s, showsLegend: true)
                    }
                    WidgetCoverageRing(summary: s)
                        .frame(width: large ? 92 : 80, height: large ? 92 : 80)
                }
                if large { statuses(s) }
            }
        } else {
            WidgetStatusMessage(icon: "square.stack", text: "Library unavailable")
        }
    }

    private func statuses(_ s: WidgetLibrarySummary) -> some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                WidgetStatTile(value: "\(s.complete)", label: "Complete", color: CardStatus.complete.color)
                WidgetStatTile(value: "\(s.downloading)", label: "Downloading", color: CardStatus.downloading.color)
            }
            GridRow {
                WidgetStatTile(value: "\(s.missing)", label: "Missing", color: CardStatus.missing.color)
                WidgetStatTile(value: "\(s.upcoming)", label: "Upcoming", color: CardStatus.upcoming.color)
            }
        }
    }
}

/// 4K coverage as a ring: the share of titles with a 4K version.
struct WidgetCoverageRing: View {
    let summary: WidgetLibrarySummary

    var body: some View {
        WidgetRing(fraction: Double(summary.fourKPercent) / 100, tint: QualityTier.uhd.color, lineWidth: 7) {
            WidgetRingLabel(percent: summary.fourKPercent, caption: "in 4K")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("4K coverage \(summary.fourKPercent) percent, \(summary.fourKTitles) of \(summary.titles) titles")
    }
}

extension WidgetLibrarySummary {
    /// `titles · 19 versions`.
    var totalsCaption: String {
        "\(titles == 1 ? "title" : "titles") · \(versions) \(versions == 1 ? "version" : "versions")"
    }
}
