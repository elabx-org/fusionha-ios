import SwiftUI

extension EnvironmentValues {
    /// How far the title's bar reaches down the page's scroll view (its top
    /// safe-area inset, status bar and navigation bar together). 0 until
    /// measured.
    @Entry var v2TitleBarInset: CGFloat = 0
}

extension View {
    /// Fades a row of glass controls out as it slides under the title's
    /// compact bar. The scroll edge effect softens text but not Liquid Glass,
    /// so a segmented control scrolled under the bar showed its labels
    /// through the title and subtitle (build 744).
    func v2FadesUnderTitleBar() -> some View { modifier(V2FadeUnderTitleBar()) }
}

private struct V2FadeUnderTitleBar: ViewModifier {
    @Environment(\.v2TitleBarInset) private var inset

    func body(content: Content) -> some View {
        // Before the first measurement, a phone's status and navigation bars.
        let bar = (inset > 0 ? inset : 100) + 4
        content.visualEffect { view, proxy in
            let top = proxy.frame(in: .scrollView).minY
            return view.opacity(min(1, max(0, (top - bar) / 24)))
        }
    }
}
