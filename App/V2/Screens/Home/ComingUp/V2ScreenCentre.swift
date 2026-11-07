import SwiftUI

// MARK: - Centring on the screen, not the content area
//
// On the folded Duo the system column takes ~84pt on the right, so a row
// centred in the content area sits left of the screen's middle (owner,
// IMG_7887). The page measures how much more inset one side has than the
// other; the Coming up carousel grows into the column by that much, so its
// focused card and dots centre on the glass. Zero on a plain iPhone.

extension EnvironmentValues {
    /// Trailing safe-area inset minus leading, in points (positive: the
    /// column is on the right).
    @Entry var screenCentreSkew: CGFloat = 0
}

private struct ScreenCentreReader: ViewModifier {
    @State private var screen: CGRect = .zero
    @State private var page: CGRect = .zero

    private var skew: CGFloat {
        guard screen.width > 0, page.width > 0 else { return 0 }
        let value = (screen.maxX - page.maxX) - (page.minX - screen.minX)
        return abs(value) < 1 ? 0 : value
    }

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { page = $0 }
            .background {
                Color.clear
                    .ignoresSafeArea()
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { screen = $0 }
            }
            .environment(\.screenCentreSkew, skew)
    }
}

extension View {
    /// Measures how far the page's centre is from the screen's, for rows
    /// that centre on the screen (`centresOnScreen`).
    func readsScreenCentre() -> some View { modifier(ScreenCentreReader()) }

    /// Grows this view into the larger safe-area side so its centre is the
    /// screen's centre. Use only on content that may run under the column
    /// (a carousel with clipping off).
    func centresOnScreen(_ skew: CGFloat) -> some View {
        padding(.trailing, -max(0, skew)).padding(.leading, min(0, skew))
    }
}
