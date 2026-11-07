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
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    /// The symbol's ink on glass: the label colour, orange only when it
    /// needs the owner (CLAUDE.md's colour rule; no green or red tiles).
    var ink: Color {
        switch self {
        case .success, .info: return .primary
        case .error, .warning: return Theme.stuck
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

/// The toast viewport: stacked glass capsules at the top of the page
/// (placed by `ToastLayer`; owner, 2026-11-07, option A). Each is
/// `symbol | message (+ action)` on clear Liquid Glass; it goes with its
/// clock, a swipe up, or VoiceOver's Dismiss.
struct ToastHost: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            ForEach(model.toasts) { toast in
                ToastCard(toast: toast, clock: model.toastClock) { model.dismissToast(toast.id) }
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: -18)))
            }
        }
        .frame(maxWidth: 440)
        .padding(.horizontal, 16)
        .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.2), value: model.toasts)
    }
}

private struct ToastCard: View {
    let toast: ToastMessage
    let clock: ToastClock
    let dismiss: () -> Void
    @AccessibilityFocusState private var voiceOverFocused: Bool

    /// One line is a capsule; a title or an action makes a rounded card.
    private var shape: AnyShape {
        toast.title == nil
            ? AnyShape(Capsule())
            : AnyShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.variant.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(toast.variant.ink)
            VStack(alignment: .leading, spacing: 1) {
                if let title = toast.title {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(toast.message).font(.footnote).foregroundStyle(.secondary)
                } else {
                    Text(toast.message).font(.subheadline.weight(.semibold))
                }
            }
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            if let action = toast.action {
                Rectangle().fill(.primary.opacity(0.2)).frame(width: 1, height: 18)
                Button(action.label) { run(action) }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.primary)
        .padding(.vertical, 11)
        .padding(.leading, 13)
        .padding(.trailing, 18)
        .glassEffect(.regular, in: shape)
        // A finger on the capsule holds its clock (the web's hover pause); a
        // swipe up sends it away.
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in clock.hold(toast.id, by: "press", true) }
                .onEnded { value in
                    clock.hold(toast.id, by: "press", false)
                    if value.translation.height < -16 { dismiss() }
                }
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

    private func run(_ action: ToastAction) {
        dismiss()
        action.handler()
    }
}
