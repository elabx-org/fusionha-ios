import SwiftUI

/// The downloading mark beside an outline badge (mock rails.js `ring`): a
/// track at 28%, the progress arc from 12 o'clock and a small down arrow,
/// all in the badge accent. 13pt at the default text size.
struct DownloadRing: View {
    /// 0...1; nil draws the track and arrow only (the client has no figure yet).
    var progress: Double?
    /// The badge row's scale (`@ScaledMetric` in the badge).
    var scale: CGFloat = 1
    @Environment(\.badgeInk) private var inkOverride

    static let size: CGFloat = 13

    var body: some View {
        let ink = inkOverride ?? .page
        let side = Self.size * scale
        // The mock's 14-unit viewBox drawn into the 13pt frame.
        let u = side / 14
        let line = 1.5 * u
        ZStack {
            Circle()
                .inset(by: (7 - 5.8) * u)
                .stroke(ink.accent.opacity(0.28), lineWidth: line)
            Circle()
                .inset(by: (7 - 5.8) * u)
                .trim(from: 0, to: min(1, max(0, progress ?? 0)))
                .stroke(ink.accent, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
            RingArrow()
                .stroke(ink.accent, style: StrokeStyle(lineWidth: 1.4 * u, lineCap: .round, lineJoin: .round))
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}

/// `M7 4.3v4.9 M5 7.3 7 9.3l2-2` in the 14-unit box.
private struct RingArrow: Shape {
    func path(in rect: CGRect) -> Path {
        let u = rect.width / 14
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * u, y: rect.minY + y * u) }
        var p = Path()
        p.move(to: pt(7, 4.3))
        p.addLine(to: pt(7, 9.2))
        p.move(to: pt(5, 7.3))
        p.addLine(to: pt(7, 9.3))
        p.addLine(to: pt(9, 7.3))
        return p
    }
}
