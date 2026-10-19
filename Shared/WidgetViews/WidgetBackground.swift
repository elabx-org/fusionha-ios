import SwiftUI
import WidgetKit

/// The widgets' background: the chosen palette's panel (the system swaps it out
/// in the accented and clear renderings). The widget follows the palette the
/// app stores in the App Group: Dark and Light are read from it, Automatic
/// follows the widget's own system appearance. This is the one place the
/// palette is resolved for a widget, so it sits at the root of every widget.
extension View {
    func fusionhaWidgetBackground() -> some View {
        modifier(WidgetPaletteBackground())
    }
}

private struct WidgetPaletteBackground: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        // Resolve the palette before any Theme colour below is read.
        let store = PaletteStore.shared
        let _ = store.systemScheme(scheme)
        content
            .environment(\.colorScheme, Theme.isLight ? .light : .dark)
            .containerBackground(for: .widget) {
                Theme.panel
            }
    }
}
