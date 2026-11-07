import SwiftUI

// MARK: - Where toasts sit (DC14)
//
// Toasts sit at the top of the page they belong to (owner, 2026-11-07: at the
// bottom they covered page actions such as Search). Whenever the screen is
// split (the Duo half open in Book pose, or the web's wide list | detail
// layout) they sit at the top of the trailing side, never across the fold
// (owner ruling; the HIG's Book-pose destination for alerts).

/// The part of a container toasts may use. `nil` means the whole container.
enum ToastRegion {
    /// The shell: the trailing column (the lower one when the fold runs side to
    /// side) whenever the shell is split, else the whole container.
    static func shell(_ split: ShellSplit, spread: SpreadContext = SpreadContext(), size: CGSize) -> CGRect? {
        if spread.spans, let page = spread.pages?.right, size.height > 0 {
            return CGRect(x: CGFloat(page.x), y: 0, width: CGFloat(page.width), height: size.height)
        }
        guard split.shown, !split.primaryHidden, size.width > 0, size.height > 0 else { return nil }
        let start = split.primary + split.gap
        switch split.axis {
        case .horizontal:
            let x = min(start, size.width)
            return CGRect(x: x, y: 0, width: size.width - x, height: size.height)
        case .vertical:
            let y = min(start, size.height)
            return CGRect(x: 0, y: y, width: size.width, height: size.height - y)
        }
    }

    /// A screen without the shell (sign-in, Settings): the trailing (or lower)
    /// side of an active fold; else `pane`, a trailing pane of the screen's own
    /// split (Settings' panel beside its sidebar), in the container's
    /// coordinates; else the whole container.
    static func trailing(_ fold: FoldInfo, pane: CGRect? = nil) -> CGRect? {
        if let x = fold.vertical {
            return CGRect(x: x.upperBound, y: 0, width: max(fold.size.width - x.upperBound, 0), height: fold.size.height)
        }
        if let y = fold.horizontal {
            return CGRect(x: 0, y: y.upperBound, width: fold.size.width, height: max(fold.size.height - y.upperBound, 0))
        }
        guard let pane else { return nil }
        let clipped = pane.intersection(CGRect(origin: .zero, size: fold.size))
        return clipped.isNull || clipped.width < 1 ? nil : clipped
    }
}

/// The toast viewport placed in `region` of its container, top-aligned, `gap`
/// below the container's top safe area.
struct ToastLayer: View {
    var region: CGRect?
    var gap: CGFloat = 8

    var body: some View {
        ToastHost()
            .padding(.top, gap)
            .frame(width: region?.width)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: region == nil ? .top : .topLeading)
            .padding(.leading, region?.minX ?? 0)
            .padding(.top, region?.minY ?? 0)
    }
}

/// A `ToastLayer` for a screen without the shell that reads the fold itself.
/// `pane` (global) is the screen's own trailing pane while it is split.
struct FoldToastLayer: View {
    var gap: CGFloat = 12
    var pane: CGRect?

    var body: some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .global).origin
            let local = pane?.offsetBy(dx: -origin.x, dy: -origin.y)
            ToastLayer(region: ToastRegion.trailing(FoldInfo(proxy), pane: local), gap: gap)
        }
    }
}
