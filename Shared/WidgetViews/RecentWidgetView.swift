import SwiftUI
import WidgetKit
import FusionhaKit

struct RecentWidgetView: View {
    let entry: RecentEntry
    let family: WidgetFamily

    var body: some View {
        Group {
            if !entry.signedIn {
                WidgetSignInPrompt(report: "")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    WidgetHeader(icon: "sparkles.tv", title: "Recently added", tint: Theme.done)
                    if entry.rows.isEmpty {
                        WidgetEmptyText(entry.failed ? "Server unreachable" : "Nothing imported yet")
                    } else {
                        switch family {
                        case .systemSmall:
                            Spacer(minLength: 0)
                            WidgetRecentHero(row: entry.rows[0], posterWidth: 46)
                        case .systemMedium:
                            WidgetPosterStrip(rows: Array(entry.rows.prefix(5)), columns: 5, showsTitle: false)
                            Spacer(minLength: 0)
                        default:
                            WidgetPosterStrip(rows: Array(entry.rows.prefix(4)), columns: 4, showsTitle: true)
                            WidgetPosterStrip(rows: Array(entry.rows.dropFirst(4).prefix(4)), columns: 4, showsTitle: true)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
        .environment(\.colorScheme, .dark)
    }
}
