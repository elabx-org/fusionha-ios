import SwiftUI
import WidgetKit
import FusionhaKit

/// Recently added: small shows the latest import alone; medium and large are
/// the shared poster strip / grid under the compact header.
struct RecentWidgetView: View {
    let entry: RecentEntry
    let family: WidgetFamily

    var body: some View {
        Group {
            if !entry.signedIn {
                WidgetSignInPrompt(report: "")
            } else if family == .systemSmall, let latest = entry.rows.first {
                WidgetRecentSmall(row: latest)
            } else if family == .systemSmall, entry.failed {
                WidgetSmallFailure(title: "Recently added")
            } else {
                VStack(alignment: .leading, spacing: WidgetStyle.headerGap) {
                    WidgetTopBar(title: "Recently added", figure: freshFigure, tint: Theme.done)
                    content.frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var content: some View {
        if entry.failed {
            WidgetRetryLine(text: "Server unreachable", intent: ReloadWidgetIntent(kind: WidgetStack.kind(for: .recent)))
        } else {
            WidgetRecentPage(rows: entry.rows, large: family == .systemLarge)
        }
    }

    /// `3 new`: imports in the last day.
    private var freshFigure: String? {
        let fresh = entry.rows.filter { row in
            row.item.importedAt.map { Date.now.timeIntervalSince($0) < 86_400 } ?? false
        }.count
        return fresh > 0 ? "\(fresh) new" : nil
    }
}
