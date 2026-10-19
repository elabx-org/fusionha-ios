import SwiftUI

/// A disabled control that still explains itself (web `GatedTip`): with a
/// reason, the control is shown off and a tap anywhere on it opens a small
/// popover with the reason; VoiceOver reads it as the hint. No reason, no change.
struct GatedTip<Content: View>: View {
    let reason: String?
    @ViewBuilder var content: () -> Content
    @State private var showing = false

    var body: some View {
        if let reason {
            content()
                .disabled(true)
                .overlay {
                    Button { showing = true } label: { Color.clear.contentShape(Rectangle()) }
                        .buttonStyle(.plain)
                        .accessibilityHidden(true)
                }
                .popover(isPresented: $showing) {
                    Text(reason)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.txt)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 260)
                        .padding(12)
                        .presentationCompactAdaptation(.popover)
                        .presentationBackground(Theme.panel2)
                }
                .accessibilityHint(reason)
        } else {
            content()
        }
    }
}
