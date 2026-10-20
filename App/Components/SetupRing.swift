import SwiftUI

/// A conic progress ring: `--grab` sweeps over a track, with a solid hole.
struct SetupRing: View {
    @Environment(\.motionEnabled) private var motion
    let fraction: Double
    var track: Color = Theme.ringTrack
    var hole: Color = Theme.ringHole
    var inset: CGFloat = 2.5

    var body: some View {
        ZStack {
            Circle().fill(track)
            RingSector(fraction: max(0, min(1, fraction))).fill(Theme.grab)
            Circle().fill(hole).padding(inset)
        }
        .animation(motion ? .easeOut(duration: 0.45) : nil, value: fraction)
    }
}

/// The swept part of a conic ring: a pie slice from 12 o'clock, clockwise.
private struct RingSector: Shape {
    var fraction: Double
    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard fraction > 0 else { return path }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.move(to: center)
        path.addArc(center: center, radius: min(rect.width, rect.height) / 2, startAngle: .degrees(-90),
                    endAngle: .degrees(-90 + 360 * fraction), clockwise: false)
        path.closeSubpath()
        return path
    }
}
