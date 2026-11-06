import SwiftUI
import FusionhaKit

/// The media-badge geometry (option A, owner 2026-11-06), in points at the
/// default text size. Everything scales by one factor (`@ScaledMetric`).
enum MediaBadgeMetrics {
    static let height: CGFloat = 15
    static let radius: CGFloat = 3.2
    /// 25, or 30 when it carries the held "!".
    static func width(held: Bool) -> CGFloat { held ? 30 : 25 }
    /// Letters: heavy, 9.6pt, +0.45 tracking.
    static let letterSize: CGFloat = 9.6
    static let letterTracking: CGFloat = 0.45
    /// Missing draws a quieter 1pt outline; downloading and held 1.3pt.
    static let thinStroke: CGFloat = 1
    static let stroke: CGFloat = 1.3
    /// Missing: outline and letters at half the ink.
    static let missingOpacity: Double = 0.5
    /// Held: the letters move left and the "!" sits 6.2 in from the right.
    static let heldShift: CGFloat = 2.6
    static let bangInset: CGFloat = 6.2
    /// Downloading with no figure yet: a static sliver of fill.
    static let unknownProgress: Double = 0.15
    /// A pair: 1pt apart when both say the same thing, 4pt when they differ.
    static let joinedGap: CGFloat = 1
    static let apartGap: CGFloat = 4
    /// Space before the "n/m" count.
    static let itemGap: CGFloat = 3

    /// A length snapped to whole device pixels.
    static func snap(_ value: CGFloat, _ displayScale: CGFloat) -> CGFloat {
        let s = max(displayScale, 1)
        return (value * s).rounded() / s
    }

    /// The download fill, 0...1.
    static func fill(_ progress: Double?) -> Double {
        min(1, max(0, progress ?? unknownProgress))
    }
}

/// One media badge drawn in its state: solid with the letters knocked out
/// (on disk, partly), a half-strength outline (missing), an outline filling
/// with the accent left to right (downloading) or an orange outline with
/// "!" inside (held).
struct MediaBadgeView: View {
    var letters: String
    var state: EditionBadgeState
    var scale: CGFloat
    var ink: BadgeInk
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private typealias M = MediaBadgeMetrics

    var body: some View {
        let w = M.snap(M.width(held: state.isHeld) * scale, displayScale)
        let h = M.snap(M.height * scale, displayScale)
        content(w: w)
            .frame(width: w, height: h)
            .accessibilityHidden(true)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: M.radius * scale, style: .continuous)
    }

    private func line(_ points: CGFloat) -> CGFloat {
        max(M.snap(points * scale, displayScale), 1 / max(displayScale, 1))
    }

    @ViewBuilder
    private func content(w: CGFloat) -> some View {
        switch state {
        case .onDisk, .partial:
            ZStack {
                shape.fill(ink.fill)
                lettersText.foregroundStyle(.black).blendMode(.destinationOut)
            }
            .compositingGroup()
        case .missing:
            ZStack {
                shape.strokeBorder(ink.label, lineWidth: line(M.thinStroke))
                lettersText.foregroundStyle(ink.label)
            }
            .opacity(M.missingOpacity)
        case let .downloading(progress):
            let p = M.fill(progress)
            ZStack {
                Rectangle()
                    .fill(ink.accent.opacity(0.9))
                    .frame(width: w * CGFloat(p))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipShape(shape)
                    .animation(reduceMotion ? nil : .smooth, value: p)
                shape.strokeBorder(ink.label, lineWidth: line(M.stroke))
                lettersText.foregroundStyle(ink.label)
            }
        case .held:
            ZStack {
                shape.strokeBorder(ink.held, lineWidth: line(M.stroke))
                lettersText.foregroundStyle(ink.held)
                    .offset(x: -M.heldShift * scale)
                letterRun("!").foregroundStyle(ink.held)
                    .offset(x: w / 2 - M.bangInset * scale)
            }
        }
    }

    private var lettersText: some View { letterRun(letters) }

    /// Heavy letters, centred: tracking adds space after the last letter,
    /// so half of it is taken back.
    private func letterRun(_ s: String) -> some View {
        Text(verbatim: s)
            .font(.system(size: M.letterSize * scale, weight: .heavy))
            .tracking(M.letterTracking * scale)
            .lineLimit(1)
            .fixedSize()
            .offset(x: M.letterTracking * scale / 2)
    }
}
