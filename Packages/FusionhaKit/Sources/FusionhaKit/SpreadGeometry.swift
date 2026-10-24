import Foundation

/// How the iPhone Duo lays out while it is open with a top-to-bottom fold
/// (inner landscape, flat or Book). A per-device choice (Settings ›
/// Appearance › "iPhone Duo, open" and the toolbar switch), never synced.
///
/// - `spread`: iOS-only. Two pages split exactly at the fold with the 40 pt
///   gutter: the tab on the left page, the picked item on the right page.
/// - `web`: the web-parity wide layout, unchanged.
public enum DuoOpenLayout: String, CaseIterable, Identifiable, Sendable {
    case spread
    case web

    /// The UserDefaults key (per device, never sent to the server).
    public static let storageKey = "fusionha.duo.openLayout"
    public static let standard = DuoOpenLayout.spread

    public var id: String { rawValue }

    /// The other mode: what the toolbar switch changes to.
    public var other: DuoOpenLayout { self == .spread ? .web : .spread }

    public var title: String { self == .spread ? "Spread" : "Web layout" }

    /// SF Symbol for the mode.
    public var symbol: String { self == .spread ? "rectangle.split.2x1" : "rectangle" }
}

/// The Spread's two pages, from a container's width and the fold inside it.
/// Pure geometry: the app reads the fold (`FoldInfo`) and lays out with these.
public enum SpreadGeometry {
    /// The narrowest a page may be; below it the container isn't a spread.
    public static let minPage = 300.0

    /// The left and right pages in the container's coordinates. The left page
    /// ends half a gutter before the fold, the right page starts half a gutter
    /// after it (the fold's real x, not the container's middle).
    public struct Pages: Equatable, Sendable {
        public var left: FoldColumns.Track
        public var right: FoldColumns.Track
        /// The fold and its gutter, between the pages.
        public var gap: Double { right.x - left.maxX }

        public init(left: FoldColumns.Track, right: FoldColumns.Track) {
            self.left = left
            self.right = right
        }
    }

    /// The pages for a container `width` wide with a top-to-bottom fold at
    /// `fold` (its x-range; zero wide when flat). `nil` when the fold isn't
    /// inside the container or a page would be under `minPage`.
    public static func pages(width: Double, fold: ClosedRange<Double>, gutter: Double = FoldColumns.gutter,
                             minPage: Double = minPage) -> Pages? {
        guard fold.lowerBound > 0, fold.upperBound < width else { return nil }
        let gap = FoldColumns.gap(around: fold, gutter: gutter)
        let left = gap.lowerBound
        let right = width - gap.upperBound
        guard left >= minPage, right >= minPage else { return nil }
        return Pages(left: FoldColumns.Track(x: 0, width: left),
                     right: FoldColumns.Track(x: gap.upperBound, width: right))
    }

    /// What the shell does with the pages.
    public enum Mode: Equatable, Sendable {
        /// Not a spread: the Web layout (or no fold).
        case off
        /// The tab on the left page, the picked item (or the tab's default) on the right.
        case pages(Pages)
        /// A browse screen asked to span both pages and nothing is picked: the
        /// tab fills the container and lays its content out in two
        /// fold-separated halves.
        case span(Pages)

        public var pages: Pages? {
            switch self {
            case .off: return nil
            case .pages(let pages), .span(let pages): return pages
            }
        }

        public var spans: Bool {
            if case .span = self { return true }
            return false
        }
    }

    /// The shell's mode: Spread needs the setting, a top-to-bottom fold and
    /// two pages of at least `minPage`; a span needs the tab to ask for it and
    /// nothing picked (a pick moves the content to the left page).
    public static func mode(layout: DuoOpenLayout, width: Double, fold: ClosedRange<Double>?,
                            spanRequested: Bool, hasItem: Bool) -> Mode {
        guard layout == .spread, let fold, let pages = pages(width: width, fold: fold) else { return .off }
        return spanRequested && !hasItem ? .span(pages) : .pages(pages)
    }
}

/// Poster columns that keep the fold in a gutter: in a Spread span `perPage`
/// columns on each page; in the Web layout with a fold the balanced split of
/// the usual count (`FoldColumns.split`); with no fold `nil` (lay out as usual).
public enum PosterTracks {
    /// Posters per page when a browse grid spans both pages (owner's mock: 3 a side).
    public static let perPage = 3

    /// The column count for a grid `count` would otherwise use.
    public static func count(base: Int, spans: Bool, perPage: Int = perPage) -> Int {
        spans ? perPage * 2 : base
    }

    /// The tracks for `count` columns across `width` (the grid's own
    /// coordinates) with the fold at `fold` in the same coordinates. A span's
    /// columns are one width on both pages.
    public static func tracks(count: Int, width: Double, fold: ClosedRange<Double>?, spans: Bool,
                              spacing: Double, gutter: Double = FoldColumns.gutter) -> [FoldColumns.Track]? {
        guard let fold else { return nil }
        let gap = FoldColumns.gap(around: fold, gutter: gutter)
        // A span's two pages share one poster size (the narrower page's).
        return FoldColumns.split(count: count, width: width, spacing: spacing, gap: gap,
                                 leading: spans ? count / 2 : nil, equalGroups: spans)
    }
}
