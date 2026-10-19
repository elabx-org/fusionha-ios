import SwiftUI
import FusionhaKit

/// A Pending row you can swipe (joint rulings, 2026-10-18). Right approves,
/// left declines. A full swipe commits (with Undo, as the deck does); a short
/// one opens to show the button, and tapping Decline there asks for a
/// reason. `peek` slides the row open once to show it can be swiped.
struct BoardSwipeRow<Content: View>: View {
    let onApprove: () -> Bool
    let onDecline: () -> Void
    let onDeclineWithReason: () -> Void
    var peek = false
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0
    @State private var settled: CGFloat = 0
    @State private var width: CGFloat = 360
    @State private var haptic = 0

    private let reveal: CGFloat = 96
    private var commit: CGFloat { max(150, width * 0.45) }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                action("Approve", "checkmark", fill: Theme.primary, text: Theme.onAccent, leading: true) { approveNow() }
                    .opacity(offset > 0 ? 1 : 0)
                Spacer(minLength: 0)
                action("Decline", "xmark", fill: Theme.danger, text: Theme.onDanger, leading: false) {
                    close()
                    onDeclineWithReason()
                }
                .opacity(offset < 0 ? 1 : 0)
            }
            .background(offset > 0 ? Theme.primary : offset < 0 ? Theme.danger : .clear)
            content()
                .offset(x: offset)
                .gesture(pan)
        }
        .clipped()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .sensoryFeedback(.impact(weight: .medium), trigger: haptic)
        .task(id: peek) {
            guard peek, !reduceMotion else { return }
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.snappy(duration: 0.35)) { offset = reveal }
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.snappy(duration: 0.35)) { offset = 0 }
        }
        .accessibilityAction(named: "Approve") { approveNow() }
        .accessibilityAction(named: "Decline") { onDecline() }
        .accessibilityAction(named: "Decline with a reason") { onDeclineWithReason() }
    }

    private func action(_ title: String, _ icon: String, fill: Color, text: Color, leading: Bool,
                        _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(text)
                .frame(width: reveal)
                .frame(maxHeight: .infinity)
                .background(fill)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHidden(true)
    }

    /// Sideways only, so a vertical drag keeps scrolling the page.
    private var pan: HorizontalPanGesture {
        HorizontalPanGesture { dx in
            let next = settled + dx
            if (abs(offset) >= commit) != (abs(next) >= commit) { haptic += 1 }
            offset = next
        } onEnded: { _ in
            if offset >= commit {
                approveNow()
            } else if offset <= -commit {
                close()
                onDecline()
            } else if abs(offset) > reveal / 2 {
                settled = offset > 0 ? reveal : -reveal
                withAnimation(.snappy) { offset = settled }
            } else {
                close()
            }
        }
    }

    private func approveNow() {
        _ = onApprove()
        close()
    }

    private func close() {
        settled = 0
        withAnimation(reduceMotion ? nil : .snappy) { offset = 0 }
    }
}
