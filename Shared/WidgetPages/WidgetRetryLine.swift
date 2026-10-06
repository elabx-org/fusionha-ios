import SwiftUI
import WidgetKit
import FusionhaKit

/// `Couldn't load · tap to retry`: a page whose data didn't arrive. The tap
/// re-shows the same page, which reloads the timeline.
struct WidgetRetryLine: View {
    let text: String
    let page: WidgetPage
    let familyKey: String

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            Button(intent: SetWidgetPageIntent(family: familyKey, page: page)) {
                Label("\(text) · tap to retry", systemImage: "arrow.clockwise")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(text). Retry")
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

/// The last reload's failure in a few monospaced words (`timeout @page library
/// 8.0s`), shown only after a failed, timed-out or killed reload.
struct WidgetDiagnosticLine: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 8, design: .monospaced))
            .foregroundStyle(.tertiary)
            .lineLimit(1)
            .truncationMode(.tail)
            .accessibilityLabel("Diagnostic: \(text)")
    }
}
