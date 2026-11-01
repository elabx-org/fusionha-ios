import SwiftUI
import FusionhaKit

/// The import bar's primary, as the plan names it. An off primary ("7 files
/// need a decision", a folder scan's "Import 0") is flat grey with muted text,
/// as the web's is, never the accent at half opacity (unreadable on Daylight).
/// A folder scan's "K need a decision" sits under it (the web's sub-line).
struct MIFooterPrimary: View {
    let plan: ManualImportFinishPlan
    /// The narrow wording (`plan.shortLabel`) when the full one doesn't fit.
    var short = false
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            primary
                .accessibilityLabel(plan.label)
                .accessibilityHint(plan.subline ?? "")
            if let subline = plan.subline {
                Text(subline)
                    .font(.caption)
                    .foregroundStyle(Theme.mut)
                    .lineLimit(1)
                    .accessibilityHidden(true)
            }
        }
    }

    private var label: String { short ? plan.shortLabel ?? plan.label : plan.label }

    private var systemImage: String? {
        plan.kind == .keep ? "internaldrive" : plan.kind == .done ? nil : "square.and.arrow.down"
    }

    @ViewBuilder
    private var primary: some View {
        if plan.disabled {
            Button {} label: {
                HStack(spacing: 6) {
                    if let systemImage { Image(systemName: systemImage).frame(width: 15, height: 15) }
                    Text(label)
                }
            }
            .buttonStyle(MIFlatOffStyle())
            .disabled(true)
        } else {
            ActAsyncButton(label: label, systemImage: systemImage, kind: .primary,
                           workingLabel: plan.kind == .keep ? "Working…" : "Importing…",
                           externalWorking: session.working) {
                await session.runPrimary()
                return session.notice?.error != true
            }
            .disabled(session.bulkBusy)
        }
    }
}

/// An off primary: flat panel grey, a hairline and muted text, in every palette.
private struct MIFlatOffStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .foregroundStyle(Theme.mut)
            .background(Theme.panel2, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.line))
    }
}
