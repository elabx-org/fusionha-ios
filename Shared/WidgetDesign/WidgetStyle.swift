import SwiftUI

/// The widgets' type scale and metrics, shared by every widget so headers,
/// rows, posters and numerals line up from one widget to the next. Nothing is
/// set below 11pt; counts and progress use big rounded numerals.
enum WidgetStyle {
    /// Header title and row titles.
    static let title = Font.system(size: 13, weight: .semibold)
    /// The one prominent title on a small widget or a hero row.
    static let heroTitle = Font.system(size: 15, weight: .semibold)
    /// Second lines, captions and legends.
    static let caption = Font.system(size: 11, weight: .medium)
    /// Uppercase section labels (`TODAY`, `LATER`).
    static let label = Font.system(size: 11, weight: .bold)

    /// Counts, percentages and times.
    static func numeral(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded).monospacedDigit()
    }

    /// Header height, and the gap under it.
    static let headerHeight: CGFloat = 18
    static let headerGap: CGFloat = 10
    /// Between list rows.
    static let rowGap: CGFloat = 8
    /// Poster corners (2:3 art); tiles and rings use `tileRadius`.
    static let posterRadius: CGFloat = 6
    static let tileRadius: CGFloat = 12
    /// A list row's poster height (2:3, so 24 × 36).
    static let rowPoster: CGFloat = 36
}
