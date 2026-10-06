import SwiftUI
import WidgetKit
import FusionhaKit

/// Recently added: a 4 × 2 poster grid with titles (large) or a 5-poster strip
/// (medium), every poster with its edition pills.
struct WidgetRecentPage: View {
    let rows: [RecentImportRow]
    let large: Bool

    var body: some View {
        if rows.isEmpty {
            WidgetStatusMessage(icon: "sparkles.tv", text: "Nothing imported yet", tint: Theme.done)
        } else {
            // The rows share the height left under the header, so posters
            // stay as large as the widget allows on every phone without overflowing.
            GeometryReader { geo in
                let poster = Self.posterHeight(available: geo.size.height, large: large)
                VStack(spacing: 12) {
                    if large {
                        strip(Array(rows.prefix(4)), poster: poster)
                        strip(Array(rows.dropFirst(4).prefix(4)), poster: poster)
                    } else {
                        WidgetPosterStrip(rows: Array(rows.prefix(5)), columns: 5, showsTitle: false,
                                          maxPosterHeight: poster)
                    }
                }
            }
        }
    }

    private func strip(_ rows: [RecentImportRow], poster: CGFloat) -> some View {
        WidgetPosterStrip(rows: rows, columns: 4, showsTitle: true, maxPosterHeight: poster)
    }

    /// A row's height less its pills (and title, large).
    private static func posterHeight(available: CGFloat, large: Bool) -> CGFloat {
        let perRow = large ? (available - 12) / 2 : available
        return max(40, perRow - 22 - (large ? 19 : 0))
    }
}
