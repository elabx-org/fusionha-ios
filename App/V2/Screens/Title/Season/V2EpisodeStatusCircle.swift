import SwiftUI
import FusionhaKit

/// An episode row's status circle (mock kit `statusCircle`), in the badge
/// ink: on disk is the filled label ink with a knocked-out check, missing
/// a dashed ring, upcoming a quiet ring with a clock, held the orange ring
/// with a pause, downloading the accent ring filling with its percent and a
/// small held mark on its foot when another version is held.
struct V2EpisodeStatusCircle: View {
    let circle: V2EpisodeState.Circle
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 28
    @Environment(\.badgeInk) private var inkOverride
    @Environment(\.pagePalette) private var page

    var body: some View {
        let ink = inkOverride ?? .page
        ZStack {
            switch circle {
            case .onDisk:
                Circle().fill(ink.fill)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.42, weight: .heavy))
                    .foregroundStyle(ink.knockout)
            case .missing:
                Circle().strokeBorder(ink.secondary, style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
            case .upcoming:
                Circle().strokeBorder(ink.track, lineWidth: 1.5)
                Image(systemName: "clock")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(ink.secondary)
            case .held:
                Circle().strokeBorder(ink.held, lineWidth: 1.5)
                Image(systemName: "pause.fill")
                    .font(.system(size: size * 0.36, weight: .bold))
                    .foregroundStyle(ink.held)
            case .downloading(let percent, let held):
                downloading(percent: percent, held: held, ink: ink)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func downloading(percent: Int?, held: Bool, ink: BadgeInk) -> some View {
        let line = size * 0.11
        Circle().stroke(ink.accent.opacity(0.22), lineWidth: line).padding(line / 2)
        Circle()
            .trim(from: 0, to: CGFloat(min(max(percent ?? 0, 0), 100)) / 100)
            .stroke(ink.accent, style: StrokeStyle(lineWidth: line, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .padding(line / 2)
        if let percent {
            Text(verbatim: "\(percent)")
                .font(.system(size: size * 0.32, weight: .bold))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .foregroundStyle(ink.accent)
        }
        if held {
            // Kit `.st .pb`: 15pt on the circle's bottom-right, ringed in the page tint.
            Image(systemName: "pause.circle.fill")
                .font(.system(size: size * 0.54))
                .foregroundStyle(ink.held)
                .background { Circle().fill(page?.tint ?? Theme.bg).padding(-2) }
                .offset(x: size * 0.39, y: size * 0.36)
        }
    }
}
