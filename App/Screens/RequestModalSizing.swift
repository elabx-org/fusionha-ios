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
