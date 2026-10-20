import SwiftUI

// MARK: - The window's size, for sheets
//
// A sheet sizes itself before it can measure anything, so a sheet that is
// form-sized on the Duo and page-sized wider (the request modal's two panes,
// fusionha D2c ruling) reads the window it is presented over. Set once at the
// root; sheets inherit it from their presenter.

extension EnvironmentValues {
    /// The app window's size; zero until the first layout pass.
    @Entry var windowSize: CGSize = .zero
}

private struct WindowSizeReader: ViewModifier {
    @State private var size: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .environment(\.windowSize, size)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
    }
}

extension View {
    /// Hands the window's size to everything below, sheets included.
    func publishesWindowSize() -> some View {
        modifier(WindowSizeReader())
    }
}
