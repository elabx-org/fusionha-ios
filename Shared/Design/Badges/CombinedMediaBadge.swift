import SwiftUI
import FusionhaKit

/// A matching HD and 4K pair as one media badge (owner, 2026-11-07, option
/// B): a single rounded shape twice a badge's width with a hairline seam
/// between the letters. On disk it is solid with the letters and the seam
/// cut out, missing is one half-strength outline, and downloading fills each
/// half with its own progress. `EditionTicketPair` uses it only when both
/// halves draw alike with nothing beside them; otherwise they sit apart.
struct CombinedMediaBadge: View {
    var hd: EditionBadgeState
    var uhd: EditionBadgeState
    var scale: CGFloat
    var ink: BadgeInk
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private typealias M = MediaBadgeMetrics

    /// Only on disk (or partly), missing and downloading combine; held keeps its "!" apart.
    static func combines(_ a: EditionBadgeState, _ b: EditionBadgeState) -> Bool {
        switch (a, b) {
        case (.onDisk, .onDisk), (.onDisk, .partial), (.partial, .onDisk), (.partial, .partial),
             (.missing, .missing), (.downloading, .downloading):
            return true
        default:
            return false
        }
    }

    var body: some View {
        let half = M.snap(M.width(held: false) * scale, displayScale)
        let h = M.snap(M.height * scale, displayScale)
        content(half: half)
            .frame(width: half * 2, height: h)
            .accessibilityHidden(true)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: M.radius * scale, style: .continuous)
    }

    private func line(_ points: CGFloat) -> CGFloat {
        max(M.snap(points * scale, displayScale), 1 / max(displayScale, 1))
    }

    private func seam(_ width: CGFloat) -> some View {
        Rectangle().frame(width: width).frame(maxHeight: .infinity)
    }

    private var letters: some View {
        HStack(spacing: 0) {
            letterRun(QualityTier.hd.badgeLetters).frame(maxWidth: .infinity)
            letterRun(QualityTier.uhd.badgeLetters).frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func content(half: CGFloat) -> some View {
        switch hd {
        case .onDisk, .partial:
            ZStack {
                shape.fill(ink.fill)
                letters.foregroundStyle(.black).blendMode(.destinationOut)
                seam(line(M.thinStroke)).foregroundStyle(.black).blendMode(.destinationOut)
            }
            .compositingGroup()
        case .missing:
            ZStack {
                shape.strokeBorder(ink.label, lineWidth: line(M.thinStroke))
                seam(line(M.thinStroke)).foregroundStyle(ink.label)
                letters.foregroundStyle(ink.label)
            }
            .opacity(M.missingOpacity)
        default:
            ZStack {
                HStack(spacing: 0) {
                    fill(progress(hd), half: half)
                    fill(progress(uhd), half: half)
                }
                .clipShape(shape)
                shape.strokeBorder(ink.label, lineWidth: line(M.stroke))
                seam(line(M.thinStroke)).foregroundStyle(ink.label)
                letters.foregroundStyle(ink.label)
            }
        }
    }

    private func progress(_ s: EditionBadgeState) -> Double {
        if case let .downloading(p) = s { return M.fill(p) }
        return 0
    }

    private func fill(_ p: Double, half: CGFloat) -> some View {
        Rectangle()
            .fill(ink.accent.opacity(0.9))
            .frame(width: half * CGFloat(p))
            .frame(width: half, alignment: .leading)
            .animation(reduceMotion ? nil : .smooth, value: p)
    }

    /// As `MediaBadgeView`'s: heavy, tracked, half the tracking taken back.
    private func letterRun(_ s: String) -> some View {
        Text(verbatim: s)
            .font(.system(size: M.letterSize * scale, weight: .heavy))
            .tracking(M.letterTracking * scale)
            .lineLimit(1)
            .fixedSize()
            .offset(x: M.letterTracking * scale / 2)
    }
}
