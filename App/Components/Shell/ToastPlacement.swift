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
}

extension View {
    /// Publishes this tab's safe-area bottom (the tab bar's top) to the shell's toasts.
    func publishesToastAnchor() -> some View {
        modifier(ToastAnchorWriter())
    }
}

private struct ToastAnchorWriter: ViewModifier {
    @Environment(ToastAnchor.self) private var anchor: ToastAnchor?

    func body(content: Content) -> some View {
        content.background {
            Color.clear.onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).maxY - proxy.safeAreaInsets.bottom
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
    static func shell(_ split: ShellSplit, size: CGSize) -> CGRect? {
        guard split.shown, size.width > 0, size.height > 0 else { return nil }
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

    /// A one-pane screen (sign-in, Settings): the trailing (or lower) side of
    /// an active fold, else the whole container.
    static func trailing(_ fold: FoldInfo) -> CGRect? {
        if let x = fold.vertical {
            return CGRect(x: x.upperBound, y: 0, width: max(fold.size.width - x.upperBound, 0), height: fold.size.height)
        }
        if let y = fold.horizontal {
            return CGRect(x: 0, y: y.upperBound, width: fold.size.width, height: max(fold.size.height - y.upperBound, 0))
        }
        return nil
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

/// A `ToastLayer` for a one-pane screen that reads the fold itself.
struct FoldToastLayer: View {
    var gap: CGFloat = 24

    var body: some View {
        GeometryReader { proxy in
            ToastLayer(region: ToastRegion.trailing(FoldInfo(proxy)), gap: gap)
        }
    }
}
