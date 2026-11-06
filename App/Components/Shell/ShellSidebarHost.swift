import SwiftUI

/// v2's sidebar on the flat open Duo (S14, mock minimize.js option A): a
/// floating glass panel inset from the display's leading edge, the tabs
/// beside it. The tabs keep their identity whether it shows or not (the
/// padding changes, never the view), so every tab keeps its scroll. v1
/// passes no sidebar, so nothing changes there.
struct ShellSidebarHost: ViewModifier {
    let make: (@MainActor (ShellSidebarToggle) -> AnyView)?
    let toggle: ShellSidebarToggle?
    let reduceMotion: Bool

    static let width: CGFloat = 248
    static let inset: CGFloat = 10

    private var shown: Bool { make != nil && toggle != nil }

    func body(content: Content) -> some View {
        content
            .padding(.leading, shown ? Self.width + Self.inset * 2 : 0)
            .overlay(alignment: .leading) {
                if let make, let toggle {
                    make(toggle)
                        .frame(width: Self.width)
                        .frame(maxHeight: .infinity)
                        .padding(Self.inset)
                        .transition(reduceMotion ? .opacity : .move(edge: .leading).combined(with: .opacity))
                }
            }
    }
}
