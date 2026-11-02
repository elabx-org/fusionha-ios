import SwiftUI

/// The Library grid's own width and the top-to-bottom fold through it, in
/// its coordinates (`FoldInfo.verticalFold`): the real fold x, so the Duo's
/// off-centre fold lands in a gutter (the old `crossesMiddle` missed it).
struct LibraryGridFold: Equatable {
    var width: CGFloat = 0
    var fold: ClosedRange<CGFloat>?

    init() {}

    init(_ proxy: GeometryProxy) {
        width = proxy.size.width
        fold = FoldInfo.verticalFold(proxy)
    }

    /// The fold through a marker in the scroll content. Its geometry changes
    /// every scroll frame, so the fold is re-read (two reserved-region
    /// queries) only when the grid's x or width or the posture changes.
    static func measured(_ proxy: GeometryProxy, bookPose: Bool) -> LibraryGridFold {
        let key = [proxy.size.width, proxy.frame(in: .global).minX, bookPose ? 1 : 0]
        if let last, last.key == key { return last.fold }
        let fold = LibraryGridFold(proxy)
        last = (key, fold)
        return fold
    }

    nonisolated(unsafe) private static var last: (key: [CGFloat], fold: LibraryGridFold)?
}

/// The Library scroll's measured width. The fold is read where it matters,
/// at its real x (`LibraryGridFold`), never assumed in the middle.
struct LibraryPane: Equatable {
    var width: CGFloat = 0
}
