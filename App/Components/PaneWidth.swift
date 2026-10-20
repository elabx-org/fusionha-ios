import SwiftUI
import FusionhaKit

// MARK: - A pane's own size (rulings L17, R4, S2)
//
// Wide layouts switch on the size a pane actually gets, never the size class:
// the Activity tab beside an open title, a Settings panel in the split's detail
// column and a page sheet each measure themselves. `PaneRule` (FusionhaKit)
// holds the thresholds.

private struct PaneSizeKey: EnvironmentKey {
    static let defaultValue: CGSize = .zero
}

extension EnvironmentValues {
    /// The measured size of the nearest pane that publishes one
    /// (`publishesPaneSize()`); zero until the first layout pass.
    var paneSize: CGSize {
        get { self[PaneSizeKey.self] }
        set { self[PaneSizeKey.self] = newValue }
    }
}

private struct PaneSizeReader: ViewModifier {
    @State private var size: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .environment(\.paneSize, size)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
    }
}

extension View {
    /// Measures this view and hands its size to everything inside it as
    /// `\.paneSize`, so wide layouts follow the pane, not the screen.
    func publishesPaneSize() -> some View {
        modifier(PaneSizeReader())
    }
}

extension CGSize {
    /// The web's desktop layout (above 720), from a measured pane.
    var isDesktopPane: Bool { PaneRule.isDesktop(Double(width)) }
}
