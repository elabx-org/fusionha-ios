import SwiftUI
import WidgetKit
import FusionhaKit

/// Recently added: a 4 × 2 poster grid with titles (large) or a 5-poster strip.
struct WidgetRecentPage: View {
    let rows: [RecentImportRow]
    let large: Bool

    var body: some View {
        if rows.isEmpty {
            WidgetEmptyText("Nothing imported yet")
        } else if large {
            VStack(spacing: 8) {
                WidgetPosterStrip(rows: Array(rows.prefix(4)), columns: 4, showsTitle: true)
                WidgetPosterStrip(rows: Array(rows.dropFirst(4).prefix(4)), columns: 4, showsTitle: true)
            }
        } else {
            WidgetPosterStrip(rows: Array(rows.prefix(5)), columns: 5, showsTitle: false)
        }
    }
}
