import SwiftUI
import FusionhaKit

// MARK: Toasts

/// The web's toast: a glass capsule near the bottom with a success / error /
/// warning tint, gone after a few seconds.
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
        content.overlay(alignment: .bottom) {
            ZStack {
                if let toast = toaster.current {
                    toastView(toast)
                        .transition(motionOff ? .opacity : .move(edge: .bottom).combined(with: .opacity))
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
        case .success: "checkmark.circle.fill"
        case .error: "xmark.octagon.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        }
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(tint).font(.system(size: 15))
            VStack(alignment: .leading, spacing: 2) {
                if let title = toast.title {
                    Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
                }
                Text(toast.message).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.txt)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button { toaster.dismiss() } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)) }
                .foregroundStyle(Theme.mut)
                .accessibilityLabel("Dismiss")
        }
        .padding(12)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }
}

extension View {
    func fetchToasts(_ toaster: FetchToaster) -> some View {
        modifier(FetchToastOverlay(toaster: toaster))
    }
}
