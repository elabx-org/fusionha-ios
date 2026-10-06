import SwiftUI
import FusionhaKit

// MARK: - Poster indicators (PosterCard `.setupRail` + `.setupRing`)

/// A title still setting up: a 3pt `--grab` shimmer rail along the poster's
/// bottom edge and a small progress ring in its bottom-right corner. Under
/// Reduce Motion the rail is a static tinted bar.
struct SetupIndicators: View {
    @Environment(\.motionEnabled) private var motion
    let fraction: Double

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack {
                Spacer(minLength: 0)
                if motion {
                    // `background-size: 200%` sliding to `-200%`: two gradient tiles scroll left.
                    GeometryReader { geo in
                        let w = geo.size.width
                        RepeatForever(animation: .linear(duration: 1.4).repeatForever(autoreverses: false)) { on in
                            HStack(spacing: 0) {
                                ForEach(0..<2, id: \.self) { _ in
                                    LinearGradient(colors: [.clear, Theme.grab, .clear],
                                                   startPoint: .leading, endPoint: .trailing)
                                        .frame(width: w * 2)
                                }
                            }
                            .offset(x: on ? -2 * w : 0)
                        }
                    }
                    .frame(height: 3)
                } else {
                    Theme.grab.opacity(0.6).frame(height: 3)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

            SetupRing(fraction: fraction)
                .frame(width: 20, height: 20)
                .overlay(Circle().strokeBorder(Theme.grab.opacity(0.45), lineWidth: 1).padding(-1))
                .padding(8)
                .accessibilityLabel("Setting up")
        }
        .allowsHitTesting(false)
    }
}

/// The step strip under the title-page hero while the title is still setting up
/// (SetupStepStrip): the current step's label + n/N, then one segment per step,
/// filled as each finishes, the running one shimmering.
struct SetupStepStrip: View {
    @Environment(\.motionEnabled) private var motion
    let setup: TitleSetup

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(setup.nowLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                Text("\(setup.doneCount)/\(setup.steps.count)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(Theme.mut)
            }
            HStack(spacing: 4) {
                ForEach(Array(setup.steps.enumerated()), id: \.offset) { _, step in
                    segment(step)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius)
                .fill(Theme.panel2)
                .overlay(RoundedRectangle(cornerRadius: Theme.radius).fill(Theme.grab.opacity(0.1)))
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func segment(_ step: SetupStep) -> some View {
        let shape = RoundedRectangle(cornerRadius: 2)
        if step.status.finished {
            shape.fill(Theme.grab).frame(height: 4).frame(maxWidth: .infinity)
                .animation(.easeOut(duration: 0.4), value: step.status.finished)
        } else if step.status == .running {
            if motion {
                shape.fill(Theme.line).frame(height: 4).frame(maxWidth: .infinity)
                    .overlay(shape.fill(Theme.grab.opacity(0.7)).shimmer().clipShape(shape))
            } else {
                shape.fill(Theme.grab).frame(height: 4).frame(maxWidth: .infinity)
            }
        } else {
            shape.fill(Theme.line).frame(height: 4).frame(maxWidth: .infinity)
        }
    }
}
