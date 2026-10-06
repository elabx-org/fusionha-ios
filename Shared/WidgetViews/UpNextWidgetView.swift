import SwiftUI
import WidgetKit
import FusionhaKit

struct UpNextWidgetView: View {
    let entry: UpNextEntry
    let family: WidgetFamily

    var body: some View {
        Group {
            if !entry.signedIn {
                WidgetSignInPrompt(report: "")
            } else {
                VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 8) {
                    WidgetHeader(icon: "calendar", title: "Up next", tint: Theme.unaired)
                    if entry.rows.isEmpty {
                        WidgetEmptyText(entry.failed ? "Server unreachable" : "Nothing airing soon")
                    } else {
                        switch family {
                        case .systemSmall:
                            Spacer(minLength: 0)
                            WidgetUpNextHero(row: entry.rows[0], posterWidth: 0)
                        case .systemMedium:
                            VStack(spacing: 6) {
                                ForEach(Array(entry.rows.prefix(3).enumerated()), id: \.offset) { _, row in
                                    WidgetUpNextRow(row: row, posterHeight: 30)
                                }
                            }
                            Spacer(minLength: 0)
                        default:
                            WidgetUpNextDayList(rows: Array(entry.rows.prefix(6)))
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
        .environment(\.colorScheme, .dark)
    }
}
