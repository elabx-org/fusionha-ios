import SwiftUI
import FusionhaKit

// MARK: Buttons

/// The web's `Button` (size sm) as a capsule: cream for primary, glass for
/// subtle and danger (danger tints the text), plain for ghost.
struct WebButtonStyle: ButtonStyle {
    enum Variant { case subtle, ghost, danger, primary }
    var variant: Variant = .subtle
    @Environment(\.isEnabled) private var enabled

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .font(.system(size: 13, weight: variant == .primary ? .bold : .semibold))
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .contentShape(Capsule())
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.5)
        switch variant {
        case .primary: label.background(Theme.primary, in: Capsule())
        case .ghost: label
        case .subtle, .danger: label.glassEffect(.regular.interactive(), in: Capsule())
        }
    }

    private var foreground: Color {
        switch variant {
        case .subtle: return Theme.txt
        case .ghost: return Theme.mut
        case .danger: return Theme.danger
        case .primary: return Theme.onAccent
        }
    }
}

extension ButtonStyle where Self == WebButtonStyle {
    static func web(_ variant: WebButtonStyle.Variant = .subtle) -> WebButtonStyle { WebButtonStyle(variant: variant) }
}

/// Loading / error placeholder for a panel body.
struct SettingsLoadingRow: View {
    var error: String?

    var body: some View {
        HStack(spacing: 10) {
            if let error {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(Theme.miss)
                Text(error).font(.system(size: 13)).foregroundStyle(Theme.mut)
            } else {
                ProgressView().controlSize(.small)
                Text("Loading…").font(.system(size: 13)).foregroundStyle(Theme.mut)
            }
        }
        .listRowBackground(Theme.card)
    }
}
