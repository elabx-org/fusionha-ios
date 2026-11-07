import SwiftUI
import FusionhaKit

// MARK: Toasts

/// The web's toast: the app's one glass toast at the top of the panel, with a
/// success / error / warning symbol, gone after a few seconds.
@MainActor
@Observable
final class FetchToaster {
    enum Tone { case success, error, warning, info }
    struct Toast: Equatable, Identifiable {
        let id = UUID()
        var title: String?
        var message: String
        var tone: Tone
    }

    private(set) var current: Toast?

    func show(_ message: String, title: String? = nil, tone: Tone = .success) {
        let toast = Toast(title: title, message: message, tone: tone)
        current = toast
        Task {
            try? await Task.sleep(for: .seconds(tone == .error ? 5 : 3.2))
            if current?.id == toast.id { current = nil }
        }
    }

    func error(_ error: Error, title: String? = nil) {
        show(error.settingsMessage, title: title, tone: .error)
    }

    func dismiss() { current = nil }
}

private struct FetchToastOverlay: ViewModifier {
    let toaster: FetchToaster
    @Environment(\.settingsMotionOff) private var motionOff

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            ZStack {
                if let toast = toaster.current {
                    toastView(toast)
                        .padding(.top, 12)
                        .transition(.glassToast(reduceMotion: motionOff))
                        .id(toast.id)
                }
            }
            .animation(motionOff ? nil : SettingsMotion.reveal(0.35), value: toaster.current)
        }
    }

    private func toastView(_ toast: FetchToaster.Toast) -> some View {
        let tint: Color = switch toast.tone {
        case .success: Theme.done
        case .error: Theme.danger
        case .warning: Theme.miss
        case .info: Theme.cyan
        }
        let icon: String = switch toast.tone {
        case .success: GlassToastSymbol.success
        case .error: GlassToastSymbol.error
        case .warning: GlassToastSymbol.warning
        case .info: GlassToastSymbol.info
        }
        return GlassToastView(symbol: icon, tint: tint, title: toast.title, message: toast.message,
                              dismiss: { toaster.dismiss() })
    }
}

extension View {
    func fetchToasts(_ toaster: FetchToaster) -> some View {
        modifier(FetchToastOverlay(toaster: toaster))
    }
}
