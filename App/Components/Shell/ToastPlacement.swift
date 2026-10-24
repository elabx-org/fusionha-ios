import SwiftUI

// MARK: - Where toasts sit (DC14)
//
// Folded, toasts float centred above the tab bar, as on the web. Whenever the
// screen is split (the Duo half open in Book pose, or the web's wide list |
// detail layout) they sit on the trailing side, never across the fold
// (owner ruling; the HIG's Book-pose destination for alerts). The gap above
// the tab bar is read from the tab's own safe area, not a constant.

/// The top of the tab bar, published by the visible tab (`TabRoot`) so the
/// shell's toasts can clear it.
@Observable
final class ToastAnchor {
    /// The bottom of the visible tab's safe area (just above the tab bar), in
    /// global coordinates. `nil` until a tab has been laid out.
    var tabSafeBottom: CGFloat?
    /// The tops of the bottom bars on screen (Library select, Activity bulk),
    /// in global coordinates, by bar.
    var barTops: [String: CGFloat] = [:]

    /// The line toasts sit above: the highest of the tab bar and any visible
    /// bottom bar.
    var floor: CGFloat? {
        ([tabSafeBottom].compactMap { $0 } + barTops.values).min()
    }
}

extension View {
    /// Publishes this tab's safe-area bottom (the tab bar's top) to the shell's toasts.
    func publishesToastAnchor() -> some View {
        modifier(ToastAnchorWriter())
    }

    /// Publishes this bottom bar's top to the shell's toasts while it is on
    /// screen, so they float above it rather than over it.
    func publishesBottomBarTop(_ id: String) -> some View {
        modifier(BottomBarTopWriter(id: id))
    }
}

private struct BottomBarTopWriter: ViewModifier {
    @Environment(ToastAnchor.self) private var anchor: ToastAnchor?
    let id: String

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { top in
                if anchor?.barTops[id] != top { anchor?.barTops[id] = top }
            }
            .onDisappear { anchor?.barTops[id] = nil }
    }
}

private struct ToastAnchorWriter: ViewModifier {
    @Environment(ToastAnchor.self) private var anchor: ToastAnchor?

    func body(content: Content) -> some View {
        content.background {
            // The background is laid out inside the tab's safe area, so its
            // bottom edge is already the tab bar's top. (`safeAreaInsets` still
            // reports the bar's inset here; subtracting it again lifted toasts
            // ~85pt too high in screenshot run 39365805012.)
            Color.clear.onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).maxY
            } action: { bottom in
                if anchor?.tabSafeBottom != bottom { anchor?.tabSafeBottom = bottom }
            }
        }
    }
}

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

/// The toast viewport placed in `region` of its container, bottom-aligned,
/// `gap` above the container's bottom safe area, or above `clearsAbove` (a
/// global y, the tab bar's top) when given.
struct ToastLayer: View {
    var region: CGRect?
    var clearsAbove: CGFloat?
    var gap: CGFloat = 12
    @State private var containerBottom: CGFloat = 0

    var body: some View {
        let lift = clearsAbove.map { max(containerBottom - $0, 0) } ?? 0
        ToastHost()
            .padding(.bottom, lift + gap)
            .frame(width: region?.width)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: region == nil ? .bottom : .bottomLeading)
            .padding(.leading, region?.minX ?? 0)
            .padding(.top, region?.minY ?? 0)
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { containerBottom = $0 }
    }
}

/// A `ToastLayer` for a screen without the shell that reads the fold itself.
/// `pane` (global) is the screen's own trailing pane while it is split.
struct FoldToastLayer: View {
    var gap: CGFloat = 24
    var pane: CGRect?
    /// A bottom bar's top (global) the toasts must clear, if one is showing.
    var clearsAbove: CGFloat?

    var body: some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .global).origin
            let local = pane?.offsetBy(dx: -origin.x, dy: -origin.y)
            ToastLayer(region: ToastRegion.trailing(FoldInfo(proxy), pane: local), clearsAbove: clearsAbove, gap: gap)
        }
    }
}
