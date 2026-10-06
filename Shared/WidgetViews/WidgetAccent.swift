import SwiftUI
import WidgetKit

// Accented rendering (a tinted Home Screen or Today View): the system draws
// every view that isn't `widgetAccentable` as a white mask of its alpha, so an
// opaque fill (a card behind a poster, a placeholder gradient) becomes a solid
// white block. Fills go through `WidgetFill`, which turns faint there.

private struct WidgetAccentPreviewKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// CI screenshots only: lays the widgets out as in accented rendering
    /// (`widgetRenderingMode` itself can't be set from the app).
    var widgetAccentPreview: Bool {
        get { self[WidgetAccentPreviewKey.self] }
        set { self[WidgetAccentPreviewKey.self] = newValue }
    }
}

/// `color` in full colour; a faint white (`accentedOpacity`) when accented.
struct WidgetFill: View {
    let color: Color
    var accentedOpacity: Double = 0.14
    @Environment(\.widgetRenderingMode) private var mode
    @Environment(\.widgetAccentPreview) private var preview

    var body: some View {
        mode == .accented || preview ? Color.white.opacity(accentedOpacity) : color
    }
}
