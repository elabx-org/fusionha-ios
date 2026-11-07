import SwiftUI
import FusionhaKit

/// A title still setting up, on its v2 page (owner, 2026-11-07, progress
/// mock): the version cards' solid surface, the current step's label and
/// "Step n of N", then one segment per step. A finished step is the page's
/// ink, the running one fills with the accent (shimmering), the rest are
/// plain track, the rails' rule. Content, so never glass.
struct V2SetupStrip: View {
    let setup: TitleSetup
    @Environment(\.pagePalette) private var page
    @Environment(\.motionEnabled) private var motion

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }
    private var current: Int { min(setup.doneCount + 1, setup.steps.count) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(setup.nowLabel.trimmingCharacters(in: CharacterSet(charactersIn: ".…")))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("Step \(current) of \(setup.steps.count)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(muted)
            }
            HStack(spacing: 4) {
                ForEach(Array(setup.steps.enumerated()), id: \.offset) { _, step in
                    segment(step)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .background { ModuleSurface(radius: 20) }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func segment(_ step: SetupStep) -> some View {
        let shape = Capsule()
        let track = shape.fill(ink.opacity(0.15)).frame(height: 4).frame(maxWidth: .infinity)
        if step.status.finished {
            shape.fill(ink.opacity(0.85)).frame(height: 4).frame(maxWidth: .infinity)
        } else if step.status == .running {
            if motion {
                track.overlay(shape.fill(Theme.i1).shimmer().clipShape(shape))
            } else {
                shape.fill(Theme.i1).frame(height: 4).frame(maxWidth: .infinity)
            }
        } else {
            track
        }
    }
}
