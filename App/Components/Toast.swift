import SwiftUI
import FusionhaKit

// MARK: Toasts (components/ui/Toast)

enum ToastVariant: Sendable {
    case success, error, warning, info

    var color: Color { token.color }

    /// The status token behind the variant (its wash and Monochrome pattern).
    var token: MonoToken {
        switch self {
        case .success: return .done
        case .error: return .danger
        case .warning: return .miss
        case .info: return .grab
        }
    }

    var symbol: String {
        switch self {
        case .success: return GlassToastSymbol.success
        case .error: return GlassToastSymbol.error
        case .warning: return GlassToastSymbol.warning
        case .info: return GlassToastSymbol.info
        }
    }
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let message: String
    var title: String?
    var variant: ToastVariant = .success
    var duration: Double = 4
    var action: ToastAction?

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool { lhs.id == rhs.id }
}

/// The toast viewport: the shell's toasts stacked at the top of the page
/// (placed by `ToastLayer`: across the page, or on the trailing side of a
/// split or fold), each the app's one glass toast (`GlassToastView`).
struct ToastHost: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            ForEach(model.toasts) { toast in
                ToastCard(toast: toast, clock: model.toastClock) { model.dismissToast(toast.id) }
                    .transition(.glassToast(reduceMotion: reduceMotion))
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.2), value: model.toasts)
    }
}

/// One shell toast. A finger on it, or VoiceOver's focus, holds its clock
/// (the web's hover pause).
private struct ToastCard: View {
    let toast: ToastMessage
    let clock: ToastClock
    let dismiss: () -> Void
    @AccessibilityFocusState private var voiceOverFocused: Bool

    var body: some View {
        GlassToastView(symbol: toast.variant.symbol, tint: toast.variant.color, title: toast.title,
                       message: toast.message, actionLabel: toast.action?.label,
                       action: toast.action?.handler, dismiss: dismiss)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in clock.hold(toast.id, by: "press", true) }
                    .onEnded { _ in clock.hold(toast.id, by: "press", false) }
            )
            .accessibilityFocused($voiceOverFocused)
            .onChange(of: voiceOverFocused) { _, focused in clock.hold(toast.id, by: "voiceover", focused) }
            .onDisappear {
                clock.hold(toast.id, by: "press", false)
                clock.hold(toast.id, by: "voiceover", false)
            }
    }
}
