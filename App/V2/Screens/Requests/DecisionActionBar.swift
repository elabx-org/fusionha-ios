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
                    Label("Decline", systemImage: "xmark.circle")
                        .labelStyle(.titleAndIcon)
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(.glass)
                .tint(Theme.danger)
                .disabled(decideDisabled)

                Button(action: onNotYet) {
                    Label("Not yet", systemImage: "clock")
                        .labelStyle(.titleAndIcon)
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(.glass)
                .disabled(decideDisabled)
                .accessibilityHint("Tells them it isn’t available yet")

                Button(action: onApprove) {
                    Label(approveLabel, systemImage: "checkmark")
                        .labelStyle(.titleAndIcon)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.primary)
                .disabled(decideDisabled || approveDisabled)
                .layoutPriority(1)
            }
            .font(.subheadline.weight(.semibold))
            .buttonBorderShape(.capsule)
            .controlSize(.large)
        }
    }
}
