import SwiftUI

/// A capsule button whose work shows on the button itself (the app's shared
/// progress behaviour):
/// - working: the icon becomes a spinner, the label stays, the width holds
///   and the button can't be tapped again;
/// - known progress (`fraction`): the capsule fills left to right instead;
/// - done: a tick for a moment, with a success tap; failed: a cross and a
///   small shake (a colour change only under Reduce Motion), then back.
/// `action` returns whether it worked; the caller still shows its own error.
struct ActAsyncButton: View {
    let label: String
    var systemImage: String? = nil
    var kind: ActButtonKind = .subtle
    var small = true
    /// A small tag after the label ("Recommended").
    var badge: String? = nil
    /// Shown instead of `label` while working ("Importing…").
    var workingLabel: String? = nil
    /// Work the caller started elsewhere (a session flag) also shows here.
    var externalWorking = false
    /// 0…1 when the work reports progress.
    var fraction: Double? = nil
    let action: () async -> Bool

    private enum Phase { case idle, working, done, failed }
    @State private var phase: Phase = .idle
    @State private var shakes = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var working: Bool { phase == .working || externalWorking }

    var body: some View {
        Button(action: run) {
            HStack(spacing: 6) {
                if systemImage != nil || working || phase != .idle { icon.frame(width: 15, height: 15) }
                Text(working ? (workingLabel ?? label) : label)
                if let badge {
                    Text(badge).font(.caption2.weight(.bold))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background((kind == .primary ? Theme.onPrimary : Theme.txt).opacity(0.18), in: Capsule())
                }
            }
        }
        .buttonStyle(ActButtonStyle(kind: kind, small: small, fill: working ? fraction : nil, tint: tint))
        .modifier(Shake(amount: reduceMotion ? 0 : 5, shakes: CGFloat(shakes)))
        .disabled(working)
        .sensoryFeedback(.success, trigger: phase) { _, new in new == .done }
        .sensoryFeedback(.error, trigger: phase) { _, new in new == .failed }
        .accessibilityValue(working ? "In progress" : phase == .done ? "Done" : phase == .failed ? "Failed" : "")
    }

    @ViewBuilder
    private var icon: some View {
        switch phase {
        case .done: Image(systemName: "checkmark").fontWeight(.bold).transition(.scale.combined(with: .opacity))
        case .failed: Image(systemName: "xmark").fontWeight(.bold)
        case .idle, .working:
            if working && fraction == nil {
                ProgressView().controlSize(.small).tint(kind == .primary ? Theme.onPrimary : Theme.txt)
            } else if let systemImage {
                Image(systemName: systemImage)
            }
        }
    }

    /// Failure tints the text red for its moment.
    private var tint: Color? { phase == .failed ? Theme.danger : nil }

    private func run() {
        guard !working else { return }
        Task { @MainActor in
            phase = .working
            let ok = await action()
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) { phase = ok ? .done : .failed }
            if !ok && !reduceMotion { withAnimation(.linear(duration: 0.36)) { shakes += 1 } }
            try? await Task.sleep(for: .seconds(ok ? 1.2 : 1.6))
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { phase = .idle }
        }
    }
}

/// A short horizontal shake, one per increment of `shakes`.
private struct Shake: GeometryEffect {
    var amount: CGFloat
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(shakes * .pi * 3), y: 0))
    }
}
