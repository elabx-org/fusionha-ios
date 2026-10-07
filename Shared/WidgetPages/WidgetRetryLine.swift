import AppIntents
import SwiftUI
import WidgetKit
import FusionhaKit

/// `Couldn't load · tap to retry`: a view whose data didn't arrive. The tap
/// runs `intent` (re-show the paged widget's page, or reload a stack widget),
/// which reloads the timeline. The last reload's failure (`timeout @page
/// library 8.0s`) sits underneath, only in this failed state.
struct WidgetRetryLine<Intent: AppIntent>: View {
    let text: String
    var diagnostic: String?
    let intent: Intent

    var body: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            Button(intent: intent) {
                Label("\(text) · tap to retry", systemImage: "arrow.clockwise")
                    .font(WidgetStyle.title)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(text). Retry")
            if let diagnostic { WidgetDiagnosticLine(text: diagnostic) }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

/// The last reload's failure in a few monospaced words.
struct WidgetDiagnosticLine: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.tertiary)
            .lineLimit(1)
            .truncationMode(.tail)
            .accessibilityLabel("Diagnostic: \(text)")
    }
}
