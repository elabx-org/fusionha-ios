import SwiftUI

// MARK: - The one toast (owner, 2026-11-07)
//
// Every toast in the app is this card: the title page's glass toast, shown at
// the TOP of the page it belongs to (bottom toasts covered page actions such as
// Search). Only the Requests Undo stays at the bottom, tied to its swipe deck,
// and it wears the same card (`glassToastCard()`).

enum GlassToastMetrics {
    /// The widest a toast card gets.
    static let maxWidth: CGFloat = 440
}

/// The toasts' symbols, one per kind.
enum GlassToastSymbol {
    static let success = "checkmark.circle.fill"
    static let info = "info.circle.fill"
    static let warning = "exclamationmark.triangle.fill"
    static let error = "xmark.octagon.fill"
}

/// A coloured symbol, an optional bold title over the message, and an
/// optional action, on clear Liquid Glass. Tap or swipe up to dismiss.
struct GlassToastView: View {
    let symbol: String
    let tint: Color
    var title: String?
    let message: String
    var actionLabel: String?
    var action: (@MainActor () -> Void)?
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(tint).font(.system(size: 16))
            VStack(alignment: .leading, spacing: 2) {
                if let title {
                    Text(title).font(.system(size: 13.5, weight: .bold)).foregroundStyle(Theme.txt)
                }
                Text(message).font(.system(size: 13)).foregroundStyle(title == nil ? Theme.txt : Theme.mut)
            }
            Spacer(minLength: 0)
            if let actionLabel, let action {
                Button(actionLabel) { run(action) }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.i2)
                    .buttonStyle(.plain)
            }
        }
        .glassToastCard()
        .onTapGesture(perform: dismiss)
        .gesture(
            DragGesture(minimumDistance: 8).onEnded { value in
                if value.translation.height < -16 { dismiss() }
            }
        )
        .accessibilityElement(children: .combine)
        .accessibilityActions {
            if let actionLabel, let action {
                Button(actionLabel) { run(action) }
            }
            Button("Dismiss notification", action: dismiss)
        }
    }

    /// Dismisses first, so an action that shows a new toast keeps it.
    private func run(_ action: @MainActor () -> Void) {
        dismiss()
        action()
    }
}

extension View {
    /// The toast card: 14 / 12 padding on 14pt-rounded glass, inset 16pt
    /// from the page's sides and never wider than 440pt: on a wide page (the
    /// open Duo, iPad) it sits centred in its region rather than stretching.
    func glassToastCard() -> some View {
        padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
            .frame(maxWidth: GlassToastMetrics.maxWidth)
            .padding(.horizontal, 16)
    }
}

extension AnyTransition {
    /// A toast dropping in from the top; a plain fade under Reduce Motion.
    static func glassToast(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .offset(y: -20))
    }
}
