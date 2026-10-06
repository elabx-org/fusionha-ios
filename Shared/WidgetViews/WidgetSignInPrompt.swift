import SwiftUI
import WidgetKit
import FusionhaKit

/// Shown until the widget can read the app's sign-in.
struct WidgetSignInPrompt: View {
    let report: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetTopBar(title: "fusionha")
            WidgetStatusMessage(icon: "person.crop.circle.badge.exclamationmark", text: "Sign in to fusionha",
                                detail: report.isEmpty ? "Open the app once to share your sign-in." : report)
        }
        .environment(\.colorScheme, .dark)
    }
}
