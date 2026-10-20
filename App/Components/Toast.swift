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
        case .success: return "checkmark"
        case .error: return "exclamationmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .info: return "info.circle"
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

/// The toast viewport: stacked, centred cards (placed by `ToastLayer`: above
/// the tab bar, or on the trailing side of a split or fold). Each card is
/// `icon | body (+ action) | dismiss` on the panel washed with its variant's
/// status (`actWash`), with a 2.5pt timer bar that drains while it isn't held.
struct ToastHost: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 10) {
            ForEach(model.toasts) { toast in
                ToastCard(toast: toast, clock: model.toastClock) { model.dismissToast(toast.id) }
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 14)))
            }
        }
        .frame(maxWidth: 420)
        .padding(.horizontal, 16)
        .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.2), value: model.toasts)
    }
}

private struct ToastCard: View {
    let toast: ToastMessage
    let clock: ToastClock
    let dismiss: () -> Void
    @AccessibilityFocusState private var voiceOverFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let vc = toast.variant.color
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: toast.variant.symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(vc)
                .frame(width: 30, height: 30)
                .background(vc.opacity(0.15), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                if let title = toast.title {
                    Text(title).font(.system(size: 13.5, weight: .bold)).foregroundStyle(Theme.txt)
                    Text(toast.message).font(.system(size: 13)).foregroundStyle(Theme.mut)
                } else {
                    Text(toast.message).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.txt)
                }
                if let action = toast.action { actionButton(action) }
            }
            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.mut)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss notification")
        }
        .padding(.top, 13)
        .padding(.trailing, 13)
        .padding(.bottom, 15)
        .padding(.leading, 15)
        .overlay(alignment: .bottomLeading) { timerBar(vc) }
        .actWash(vc, mono: toast.variant.token, radius: Theme.radius, base: Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .shadow(color: .black.opacity(0.55), radius: 22, y: 18)
        // A finger on the card holds its clock (the web's hover pause).
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in clock.hold(toast.id, by: "press", true) }
                .onEnded { _ in clock.hold(toast.id, by: "press", false) }
        )
        .accessibilityElement(children: .combine)
        .accessibilityFocused($voiceOverFocused)
        .accessibilityActions {
            if let action = toast.action {
                Button(action.label) { run(action) }
            }
            Button("Dismiss notification", action: dismiss)
        }
        .onChange(of: voiceOverFocused) { _, focused in clock.hold(toast.id, by: "voiceover", focused) }
        .onDisappear {
            clock.hold(toast.id, by: "press", false)
            clock.hold(toast.id, by: "voiceover", false)
        }
    }

    private func actionButton(_ action: ToastAction) -> some View {
        Button { run(action) } label: {
            HStack(spacing: 5) {
                Text(action.label)
                Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold))
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.accentText)
            .padding(.top, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func run(_ action: ToastAction) {
        dismiss()
        action.handler()
    }

    /// Drains with the clock; a still, full bar under Reduce Motion (web).
    private func timerBar(_ color: Color) -> some View {
        let fraction = reduceMotion ? 1 : (clock.remaining[toast.id] ?? 1)
        return GeometryReader { geo in
            Rectangle().fill(color.opacity(0.55))
                .frame(width: geo.size.width * fraction, height: 2.5)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .animation(reduceMotion ? nil : .linear(duration: ToastCountdown.tick), value: fraction)
        }
        .accessibilityHidden(true)
    }
}
