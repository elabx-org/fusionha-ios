import SwiftUI
import FusionhaKit

extension View {
    /// Keeps the view before the fold's gutter when a top-to-bottom fold runs
    /// through the space it was given (a list, a notice or a full-width button
    /// on the open iPhone Duo, either layout); full width otherwise. The
    /// measuring frame is always full width, so narrowing never re-measures.
    /// `enabled` false keeps the full width (and the view's identity). The
    /// Web layout's Library filter field uses it too.
    func foldLeadingColumn(_ enabled: Bool = true) -> some View {
        modifier(FoldLeadingColumn(enabled: enabled))
    }
}

private struct FoldLeadingColumn: ViewModifier {
    let enabled: Bool
    @State private var lead: CGFloat?

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: enabled ? lead ?? .infinity : .infinity, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            // S2's tested maths (`LibraryFoldTests`): half a gutter before the
            // fold, nothing when the fold isn't inside the view.
            .onGeometryChange(for: CGFloat?.self) { proxy in
                LibraryFold.filterWidth(width: Double(proxy.size.width), fold: proxy.foldRange).map { CGFloat($0) }
            } action: { lead = $0 }
    }
}
