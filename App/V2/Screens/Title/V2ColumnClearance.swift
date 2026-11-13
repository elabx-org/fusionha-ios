import SwiftUI

/// The title page under the Duo's column (collapsed tabs, full width): the
/// art, cards and text run to the display's edge, but anything you tap stops
/// at the column's edge, so the column never takes a tap meant for it
/// (owner-approved mock 2026-11-13: Review and the tab strip went dead once
/// scrolled under the arrow and Close). Zero everywhere else.
extension EnvironmentValues {
    @Entry var v2ColumnClearance: CGFloat = 0
}

extension View {
    /// Keeps this control's trailing edge clear of the Duo's column.
    func v2ClearsColumn() -> some View { modifier(V2ClearsColumn()) }
}

private struct V2ClearsColumn: ViewModifier {
    @Environment(\.v2ColumnClearance) private var clearance

    func body(content: Content) -> some View {
        content.padding(.trailing, clearance)
    }
}
