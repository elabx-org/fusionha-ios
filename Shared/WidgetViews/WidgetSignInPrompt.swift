import SwiftUI
import WidgetKit
import FusionhaKit

struct WidgetSignInPrompt: View {
    let report: String

    var body: some View {
        VStack(spacing: 4) {
            Label("Sign in to fusionha", systemImage: "person.crop.circle.badge.exclamationmark")
                .font(.caption)
            Text("Open the app once to share your sign-in.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            // Shows why this widget can't see the app's sign-in (App Group,
            // team keychain), so a re-signed build can be checked on device.
            if !report.isEmpty {
                Text(report)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
            }
        }
        .environment(\.colorScheme, .dark)
    }
}
