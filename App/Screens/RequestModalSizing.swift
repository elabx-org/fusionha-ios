import SwiftUI

/// The request modal's sheet size: a form sheet on the Duo (R3), page-sized
/// when the window is desktop-wide so its two panes show, and the presenter's
/// own size inside the Add sheet.
struct RequestModalSizing: ViewModifier {
    let formSized: Bool
    let wide: Bool

    func body(content: Content) -> some View {
        if !formSized {
            content
        } else if wide {
            content.presentationSizing(.page)
        } else {
            content.formSheet()
        }
    }
}

/// The request sheet's surface. v1: the solid panel, 14pt corners. v2: the
/// system's glass sheet (look pass family 5); inside the Add sheet, which
/// has no glass of its own under it, the page's panel stays.
struct RequestModalChrome: ViewModifier {
    let formSized: Bool

    func body(content: Content) -> some View {
        if ProductLook.isV2 {
            content
                .background(formSized ? Color.clear : Theme.panel)
                .presentationDragIndicator(.visible)
        } else {
            content
                .background(Theme.panel)
                .presentationDragIndicator(.visible)
                .sheetBackground(Theme.panel)
                .presentationCornerRadius(14)
        }
    }
}
