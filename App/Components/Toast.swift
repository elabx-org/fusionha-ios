import SwiftUI
import FusionhaKit

// MARK: Toasts (components/ui/Toast)

enum ToastVariant: Sendable {
    case success, error, warning, info

    var color: Color {
        switch self {
        case .success: return Theme.done
        case .error: return Theme.danger
        case .warning: return Theme.miss
        case .info: return Theme.grab
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

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool { lhs.id == rhs.id }
}

/// The toast viewport: stacked, centred cards above the tab bar. Each card is
/// `icon | body | dismiss` on a translucent panel washed with its variant
/// colour, with a 2.5pt timer bar draining over its duration.
struct ToastHost: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 10) {
            ForEach(model.toasts) { toast in
                ToastCard(toast: toast) { model.dismissToast(toast.id) }
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
    let dismiss: () -> Void
    @State private var drained = false
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
            .accessibilityLabel("Dismiss")
        }
        .padding(.top, 13)
        .padding(.trailing, 13)
        .padding(.bottom, 15)
        .padding(.leading, 15)
        .background {
            ZStack(alignment: .leading) {
                Rectangle().fill(.ultraThinMaterial)
                Theme.panel.opacity(0.92)
                LinearGradient(colors: [vc.opacity(0.16), .clear], startPoint: .leading, endPoint: .trailing)
            }
        }
        .overlay(alignment: .bottomLeading) {
            GeometryReader { geo in
                Rectangle().fill(vc.opacity(0.55))
                    .frame(width: drained ? 0 : geo.size.width, height: 2.5)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.line))
        .shadow(color: .black.opacity(0.55), radius: 22, y: 18)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: toast.duration)) { drained = true }
        }
        .accessibilityElement(children: .combine)
    }
}

