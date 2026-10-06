import SwiftUI
import WidgetKit
import FusionhaKit

/// Wraps a row in a `Link` when it has somewhere to go (medium and large only:
/// small widgets open their `widgetURL`).
struct WidgetRowLink<Content: View>: View {
    let url: URL?
    @ViewBuilder var content: Content

    var body: some View {
        // Plain, so row text keeps the widget's colours instead of the link tint.
        if let url {
            // A rectangular content shape so the whole row (gaps included) is
            // the tap region, not only its drawn pixels.
            Link(destination: url) { content.foregroundStyle(.primary).contentShape(Rectangle()) }
                .buttonStyle(.plain)
        } else {
            content
        }
    }
}
