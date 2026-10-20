import SwiftUI

// The Requests area's wide layouts (iPhone Duo unfolded in landscape, an
// iPad; batch D2a, rows DU1–DU5). The web switches its Requests chrome at a
// 720 px viewport (`usePhoneLayout`, `useTriageLayout`); here the switch is
// the Requests pane's own measured width against 720 (rulings L17, R4, S2),
// never the size class. So the Duo's inner display in portrait (about 669)
// keeps the phone layouts (Q-DC3), and so does the Requests column while a
// title is open beside it.

/// Whether a Requests pane is wide enough for the web's desktop layouts.
enum RequestsWideRule {
    /// The web's `useIsMobile` breakpoint.
    static let viewport: CGFloat = 720
    /// Discover's side margins (16 + 16): the web's 720 counts the page
    /// padding, the measured width here doesn't.
    static let margins: CGFloat = 32

    static func isWide(contentWidth: CGFloat) -> Bool {
        contentWidth + margins >= viewport
    }
}

extension EnvironmentValues {
    /// True when the Requests pane uses the web's desktop layouts (DU1–DU5).
    @Entry var requestsWide = false
}

/// Wide, the views scroll inside their own panes (the web's sticky decision
/// card, its fixed-height Board columns, the thread panel), so the view takes
/// the visible height of the page's scroll view, less the room above it.
/// Off, the view keeps its natural height; the modifier stays applied either
/// way so switching never rebuilds the view (its models, its scroll).
struct RequestsViewportHeight: ViewModifier {
    let on: Bool
    /// The visible height of the page's scroll view.
    @State private var container: CGFloat = 0
    /// The view's top in the page's scroll view, measured once (at rest the
    /// page is at its top), so the panes end at the bottom of the screen.
    @State private var top: CGFloat?

    private var height: CGFloat? {
        guard on, container > 0 else { return nil }
        return max(container - (top ?? 140) - Theme.pageBottom, 420)
    }

    func body(content: Content) -> some View {
        content
            .frame(height: height, alignment: .top)
            .background {
                Color.clear
                    .containerRelativeFrame(.vertical)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { container = $0 }
                    .accessibilityHidden(true)
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .scrollView(axis: .vertical)).minY
            } action: { minY in
                if top == nil { top = min(max(minY, 0), 260) }
            }
    }
}

/// A panel's width on the trailing side: the web's 460, or, when a fold runs
/// top to bottom through the container (active or not), exactly the far side
/// of it, so the panel never straddles the hinge and its edge never sits on
/// it (HIG Duo checklist §6). The Duo's far half is about 470, so the panel
/// keeps the web's size there.
enum TrailingPanelWidth {
    static let standard: CGFloat = 460

    static func width(_ proxy: GeometryProxy) -> CGFloat {
        let width = proxy.size.width
        guard #available(iOS 27.1, *) else { return min(standard, width) }
        let fold = proxy.reservedRegions(kind: .division, options: .includeInactive)
            .map(\.frame)
            .first { $0.height >= $0.width && $0.maxX < width && $0.minX > 0 }
        if let fold { return max(width - fold.maxX, 0) }
        return min(standard, width)
    }
}
