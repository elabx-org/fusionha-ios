import SwiftUI
import WidgetKit
import FusionhaKit

/// Recently added: small shows the latest import's poster edge to edge;
/// medium and large are the shared poster row / grid under the compact header.
/// The widget runs with its content margins off (for the small poster), so
/// medium and large pad themselves by the system margins.
struct RecentWidgetView: View {
    let entry: RecentEntry
    let family: WidgetFamily
    @Environment(\.widgetContentMargins) private var margins

    var body: some View {
        Group {
            if family == .systemSmall, entry.signedIn, let latest = entry.rows.first {
                WidgetRecentSmall(row: latest, bleed: true)
            } else {
                padded.padding(margins)
            }
        }
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var padded: some View {
        if !entry.signedIn {
            WidgetSignInPrompt(report: "")
        } else if family == .systemSmall, entry.failed {
            WidgetSmallFailure(title: "Recently added")
        } else {
            VStack(alignment: .leading, spacing: WidgetStyle.headerGap) {
                WidgetTopBar(title: "Recently added", figure: todayFigure)
                content.frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if entry.failed {
            WidgetRetryLine(text: "Server unreachable", intent: ReloadWidgetIntent(kind: WidgetStack.kind(for: .recent)))
        } else {
            WidgetRecentPage(rows: entry.rows, large: family == .systemLarge)
        }
    }

    /// `7 today`: imports since midnight.
    private var todayFigure: String? {
        let today = entry.rows.filter { row in
            row.item.importedAt.map { Calendar.current.isDateInToday($0) } ?? false
        }
        return today.isEmpty ? nil : "\(today.count) today"
    }
}
