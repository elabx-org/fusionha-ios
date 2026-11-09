import SwiftUI

/// The grounds the open Duo's pages are painting, so the strip in the fold
/// in book pose (`V2FoldSeam`) can run each page's own ground into the
/// gutter instead of guessing it from the open title. Pages register only
/// in book pose (`PageGroundModifier`); nothing reads this otherwise.
@MainActor
@Observable
final class PaneGrounds {
    struct Report: Equatable {
        let palette: PagePalette
        let recipe: PageGround.Recipe
        let art: URL?
        let artHeight: CGFloat
        let artOpacity: GroundArtOpacity
        /// In global coordinates, rounded to whole points.
        let frame: CGRect
    }

    private(set) var reports: [UUID: Report] = [:]

    func set(_ id: UUID, _ report: Report?) {
        guard reports[id] != report else { return }
        reports[id] = report
    }

    /// The page whose trailing edge meets the fold at `x` (the list side).
    func leading(of x: CGFloat) -> Report? {
        reports.values
            .filter { abs($0.frame.maxX - x) < 30 && $0.frame.width > 120 }
            .max { $0.frame.minX < $1.frame.minX }
    }

    /// The page whose leading edge meets the fold at `x` (the title side).
    func trailing(of x: CGFloat) -> Report? {
        reports.values
            .filter { abs($0.frame.minX - x) < 30 && $0.frame.width > 120 }
            .min { $0.frame.maxX < $1.frame.maxX }
    }
}

extension EnvironmentValues {
    @Entry var paneGrounds: PaneGrounds? = nil
}
