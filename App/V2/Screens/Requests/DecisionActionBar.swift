import SwiftUI

/// The decision's three choices (mock requests.js `rq-acts` / `rq-abar`):
/// Decline (asks for a reason), Not yet (defers as "not available yet") and
/// Approve, the one prominent action. Glass, as controls are; Approve is the
/// solid accent. On the wide pane Approve names its versions.
struct DecisionActionBar: View {
    let approveLabel: String
    var approveDisabled = false
    var decideDisabled = false
    let onDecline: () -> Void
    let onNotYet: () -> Void
    let onApprove: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button(action: onDecline) {
                    choice("Decline", "xmark.circle")
                }
                .buttonStyle(.glass)
                .tint(Theme.danger)
                .disabled(decideDisabled)

                Button(action: onNotYet) {
                    choice("Not yet", "clock")
                }
                .buttonStyle(.glass)
                .disabled(decideDisabled)
                .accessibilityHint("Tells them it isn’t available yet")

                Button(action: onApprove) {
                    choice(approveLabel, "checkmark")
                        .foregroundStyle(.white)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.primary)
                .disabled(decideDisabled || approveDisabled)
                .layoutPriority(1)
            }
            .font(.subheadline.weight(.semibold))
            .buttonBorderShape(.capsule)
        }
    }

    /// Icon and word side by side, always (a Label can drop its title).
    private func choice(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Capsule())
    }
}
