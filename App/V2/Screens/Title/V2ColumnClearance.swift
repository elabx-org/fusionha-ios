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

extension View {
    /// A sideways row of controls (chips, scopes, filters) drawn past its
    /// edge (`scrollClipDisabled`): with the Duo's column beside it, it clips
    /// at the column's edge instead, so a chip never sits under the clock or
    /// the arrow (owner's review, 2026-11-18: Activity's and All titles'
    /// chips ran under the folded column). It still scrolls in full.
    func v2ClipsAtColumn() -> some View { modifier(V2ClipsAtColumn()) }
}

private struct V2ClipsAtColumn: ViewModifier {
    @Environment(\.v2ColumnClearance) private var clearance

    func body(content: Content) -> some View {
        content.scrollClipDisabled(clearance == 0)
    }
}
