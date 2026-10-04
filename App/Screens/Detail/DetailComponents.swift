import SwiftUI
import UIKit
import FusionhaKit

// Small building blocks shared by the Detail*.swift files: tokens the theme
// lacks, the web's motion (kept local to the detail page), section headers,
// scope pills, status pills, glass rails and the toast.

enum DetailTokens {
    /// `--line2` (undefined in the web CSS; its intended value).
    static let line2 = Color.white.opacity(0.14)
    static let star = Color(hex: 0xF5C518)
    /// Text on the gradient quality badge.
    static let badgeText = Color(hex: 0x08131A)

    static func tier(_ tier: QualityTier) -> Color { tier == .hd ? Theme.edition : Theme.grab }

    static func dot(_ dot: EditionDot) -> Color {
        switch dot {
        case .upgrade: return Theme.edition
        case .grab: return Theme.grab
        case .done: return Theme.done
        case .miss: return Theme.miss
        }
    }
}

extension Color {
    /// CSS `color-mix(in srgb, self p%, other)`.
    func mix(_ p: Double, _ other: Color) -> Color {
        let a = UIColor(self).rgba, b = UIColor(other).rgba
        return Color(red: a.0 * p + b.0 * (1 - p), green: a.1 * p + b.1 * (1 - p),
                     blue: a.2 * p + b.2 * (1 - p), opacity: a.3 * p + b.3 * (1 - p))
    }
}

private extension UIColor {
    var rgba: (Double, Double, Double, Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
}

// MARK: - Motion

/// True when motion should be dropped: the system Reduce Motion setting, or the
/// server's "Animations" switch turned off (the web's ReduceMotionProvider).
private struct DetailReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var detailReduceMotion: Bool {
        get { self[DetailReduceMotionKey.self] }
        set { self[DetailReduceMotionKey.self] = newValue }
    }
}

/// The web's easing curves and durations.
enum DetailMotion {
    /// `REVEAL_EASE` (motion/Reveal.tsx).
    static func reveal(_ duration: Double = 0.5) -> Animation { .timingCurve(0.52, 0.01, 0.16, 1, duration: duration) }
    /// Coverage bar width (`width 0.4s cubic-bezier(.65,0,.35,1)`).
    static let barFill = Animation.timingCurve(0.65, 0, 0.35, 1, duration: 0.4)
    /// The flyout's `cubic-bezier(.32,.72,0,1)`.
    static let sheet = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.44)
    /// The overshooting pop of the search button (`cubic-bezier(.34,1.6,.5,1)`).
    static let pop = Animation.timingCurve(0.34, 1.6, 0.5, 1, duration: 0.25)
    static let quick = Animation.easeInOut(duration: 0.15)
}

extension View {
    /// `.animation(_:value:)` that turns off under reduced motion.
    func detailAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(DetailAnimationModifier(animation: animation, value: value))
    }

    /// Opacity breathing between `low` and `high` (`coverPulse`, `pausePulse`…). Static under reduced motion.
    func detailPulse(low: Double = 0.6, high: Double = 1, period: Double = 1.5, active: Bool = true) -> some View {
        modifier(PulseModifier(low: low, high: high, period: period, active: active))
    }

    /// A continuous rotation (spinners). Static under reduced motion.
    func detailSpin(period: Double = 0.9) -> some View {
        modifier(SpinModifier(period: period))
    }

    /// Fade-and-rise entrance (`Reveal`): from `y` below and transparent, once.
    func detailReveal(delay: Double = 0, y: CGFloat = 14, duration: Double = 0.5) -> some View {
        modifier(RevealModifier(delay: delay, y: y, duration: duration))
    }

    /// The horizontal `shake` keyframe, replayed whenever `trigger` changes.
    func detailShake(trigger: Int) -> some View {
        modifier(ShakeModifier(trigger: trigger))
    }
}

private struct DetailAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.detailReduceMotion) private var reduce
    let animation: Animation
    let value: V
    func body(content: Content) -> some View {
        content.animation(reduce ? nil : animation, value: value)
    }
}

private struct PulseModifier: ViewModifier {
    @Environment(\.detailReduceMotion) private var reduce
    let low: Double, high: Double, period: Double, active: Bool
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .opacity(reduce || !active ? 1 : (on ? high : low))
            .onAppear {
                guard !reduce, active else { return }
                withAnimation(.easeInOut(duration: period / 2).repeatForever(autoreverses: true)) { on = true }
            }
    }
}

private struct SpinModifier: ViewModifier {
    @Environment(\.detailReduceMotion) private var reduce
    let period: Double
    @State private var angle = 0.0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle))
            .onAppear {
                guard !reduce else { return }
                withAnimation(.linear(duration: period).repeatForever(autoreverses: false)) { angle = 360 }
            }
    }
}

private struct RevealModifier: ViewModifier {
    @Environment(\.detailReduceMotion) private var reduce
    let delay: Double, y: CGFloat, duration: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown || reduce ? 1 : 0)
            .offset(y: shown || reduce ? 0 : y)
            .onAppear {
                guard !shown else { return }
                if reduce { shown = true; return }
                withAnimation(DetailMotion.reveal(duration).delay(delay)) { shown = true }
            }
    }
}

private struct ShakeEffect: GeometryEffect {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        // 0 → -3 → +3 → 0 over one cycle, like the web's `shake`.
        ProjectionTransform(CGAffineTransform(translationX: -3 * sin(progress * .pi * 2), y: 0))
    }
}

private struct ShakeModifier: ViewModifier {
    @Environment(\.detailReduceMotion) private var reduce
    let trigger: Int
    func body(content: Content) -> some View {
        content
            .modifier(ShakeEffect(progress: CGFloat(trigger)))
            .animation(reduce ? nil : .easeInOut(duration: 0.4), value: trigger)
    }
}

/// A spinning ring (`.spin` / `analysisSpin` / `download-pill-spin`).
struct DetailSpinner: View {
    var size: CGFloat = 15
    var color: Color = Theme.cyan
    var period: Double = 0.65

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .background(Circle().stroke(DetailTokens.line2, lineWidth: 2))
            .frame(width: size, height: size)
            .detailSpin(period: period)
    }
}

/// Diagonal white stripes sliding along a downloading fill (`seasonBarStripe`, 18px period, 0.85s).
struct DetailStripes: View {
    @Environment(\.detailReduceMotion) private var reduce

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduce)) { timeline in
            let phase = reduce ? 0 : CGFloat(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 0.85) / 0.85) * 18
            Canvas { context, size in
                var x = -size.height - 18 + phase
                while x < size.width + 18 {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x + size.height, y: 0))
                    path.addLine(to: CGPoint(x: x + size.height + 6, y: 0))
                    path.addLine(to: CGPoint(x: x + 6, y: size.height))
                    path.closeSubpath()
                    context.fill(path, with: .color(.white.opacity(0.28)))
                    x += 18
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Section header

/// `.sec`: mono 800 11px, tracking .11em, uppercase, `--dim`, with an optional `--i2` see-label.
struct DetailSection: View {
    let title: String
    var see: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(1.21)
                .foregroundStyle(Theme.dim)
            Spacer(minLength: 8)
            if let see {
                Text(see).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.cyan)
            }
        }
        .padding(.top, 22)
        .padding(.bottom, 9)
        .padding(.horizontal, 2)
    }
}

/// The 11px uppercase row label of the switcher rows (`ACT ON`, `VERSION`).
struct DetailRowLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11))
            .tracking(0.55)
            .foregroundStyle(Theme.dim)
    }
}

// MARK: - Pills

/// The switcher's `fpill`: a glass capsule control, tinted when active.
struct DetailScopePill<Content: View>: View {
    let active: Bool
    var tint: Color? = nil
    let action: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        let accent = tint ?? Theme.txt
        Button(action: action) {
            HStack(spacing: 8) { content }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(active ? accent : Theme.mut)
                .lineLimit(1)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .frame(minHeight: 32)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(active ? .regular.tint((tint ?? Theme.card).opacity(tint == nil ? 0.8 : 0.14)).interactive()
                            : .regular.interactive(), in: .capsule)
        .overlay(Capsule().strokeBorder(active ? (tint.map { $0.mix(0.45, Theme.panel2) } ?? Theme.line) : Theme.line))
        .detailAnimation(DetailMotion.quick, value: active)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

/// The dashed "+ edition" / "+ version" add chip.
struct DetailAddChip: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus").font(.system(size: 12, weight: .semibold))
                Text(label)
            }
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(Theme.mut)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .frame(minHeight: 32)
            .overlay(Capsule().strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// A 7pt status dot.
struct DetailDot: View {
    let color: Color
    var size: CGFloat = 7
    var body: some View { Circle().fill(color).frame(width: size, height: size) }
}

/// The HD + UHD dots overlapped by -4 (the All header).
struct DetailDualDots: View {
    var body: some View {
        HStack(spacing: -4) {
            DetailDot(color: Theme.edition, size: 9)
            DetailDot(color: Theme.grab, size: 9)
        }
    }
}

/// `rState`: the coverage/status pill of a reveal header or card.
enum DetailStatePillKind: Hashable {
    case ok(String), part(String), want, soon, upgrading

    var color: Color {
        switch self {
        case .ok: return Theme.done
        case .part: return Theme.grab
        case .want: return Theme.miss
        case .soon: return Theme.unaired
        case .upgrading: return Theme.edition
        }
    }
}

struct DetailStatePill: View {
    let kind: DetailStatePillKind

    var body: some View {
        HStack(spacing: 4) {
            switch kind {
            case .ok(let text): Text("● " + text)
            case .part(let text): Text("◐ " + text)
            case .want: Text("○ Wanted")
            case .soon:
                Image(systemName: "clock").font(.system(size: 10, weight: .semibold)).detailPulse(low: 0.4, high: 1, period: 2)
                Text("Upcoming")
            case .upgrading:
                Image(systemName: "arrow.up").font(.system(size: 10, weight: .bold))
                Text("Upgrading")
            }
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(kind.color)
        .lineLimit(1)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(kind.color.opacity(0.13), in: Capsule())
        .overlay(Capsule().strokeBorder(kind.color.opacity(0.32)))
        .fixedSize()
    }
}

/// The owned-quality chip (`DetailQualityChip`): mono 10/700, tier coloured.
struct DetailQualityChip: View {
    let quality: String?
    let tier: QualityTier

    var body: some View {
        let color = DetailTokens.tier(tier)
        Text(DetailText.quality(quality))
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(color.opacity(0.3)))
    }
}

/// A version tag (`Black & White`) next to a tier label.
struct DetailVersionTag: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Theme.mut)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
    }
}

// MARK: - Glass rails

/// An icon button inside a glass rail (`rbtn` / per-edition rail buttons).
struct DetailRailButton: View {
    let systemImage: String
    let label: String
    var size: CGFloat = 44
    var glyph: CGFloat = 18
    var tint: Color = Theme.mut
    var busy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if busy {
                    DetailSpinner(size: glyph - 2, color: Theme.cyan)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: glyph, weight: .regular))
                        .foregroundStyle(tint)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
        }
        .buttonStyle(DetailPressStyle())
        .disabled(busy)
        .accessibilityLabel(label)
    }
}

/// Press-to-scale `.9` (the web's `:active { transform: scale(.9) }`).
struct DetailPressStyle: ButtonStyle {
    @Environment(\.detailReduceMotion) private var reduce
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduce ? 0.9 : 1)
            .animation(reduce ? nil : DetailMotion.pop, value: configuration.isPressed)
    }
}

/// Bordered square action button (episode/movie card actions: 40–44pt, `--panel2`).
struct DetailSquareAction: View {
    let systemImage: String
    let label: String
    var size: CGFloat = 44
    var tint: Color = Theme.mut
    var busy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if busy { DetailSpinner(size: 15) } else {
                    Image(systemName: systemImage).font(.system(size: 16)).foregroundStyle(tint)
                }
            }
            .frame(width: size, height: size)
            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line))
        }
        .buttonStyle(DetailPressStyle())
        .disabled(busy)
        .accessibilityLabel(label)
    }
}

// MARK: - Bars

/// A rounded coverage bar with owned + grabbing segments that animate their width.
struct DetailCoverageBar: View {
    let total: Int
    let owned: Int
    var grabbing: Int = 0
    let color: Color
    var height: CGFloat = 8
    var track: Color = Theme.txt.opacity(0.09)
    @State private var shown = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let ownedW = total > 0 ? w * CGFloat(owned) / CGFloat(total) : 0
            let grabW = total > 0 ? w * CGFloat(grabbing) / CGFloat(total) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                HStack(spacing: 0) {
                    Rectangle().fill(color).frame(width: shown ? ownedW : 0)
                    if grabbing > 0 {
                        Rectangle().fill(Theme.grab).frame(width: shown ? grabW : 0).detailPulse()
                    }
                }
                .clipShape(Capsule())
            }
        }
        .frame(height: height)
        .detailAnimation(DetailMotion.barFill, value: shown)
        .detailAnimation(DetailMotion.barFill, value: owned)
        .onAppear { shown = true }
    }
}

// MARK: - Toast

struct DetailToast: Identifiable, Equatable {
    enum Variant { case success, info, warning, error }
    let id = UUID()
    var title: String?
    var message: String
    var variant: Variant = .info
    var actionLabel: String?
    var action: (() -> Void)?

    static func == (a: DetailToast, b: DetailToast) -> Bool { a.id == b.id }

    var color: Color {
        switch variant {
        case .success: return Theme.done
        case .info: return Theme.cyan
        case .warning: return Theme.miss
        case .error: return Theme.danger
        }
    }

    var symbol: String {
        switch variant {
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }
}

struct DetailToastView: View {
    let toast: DetailToast
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: toast.symbol).foregroundStyle(toast.color).font(.system(size: 16))
            VStack(alignment: .leading, spacing: 2) {
                if let title = toast.title {
                    Text(title).font(.system(size: 13.5, weight: .bold)).foregroundStyle(Theme.txt)
                }
                Text(toast.message).font(.system(size: 13)).foregroundStyle(toast.title == nil ? Theme.txt : Theme.mut)
            }
            Spacer(minLength: 0)
            if let label = toast.actionLabel, let action = toast.action {
                Button(label) { action(); dismiss() }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.cyan)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
        .padding(.horizontal, 16)
        .onTapGesture(perform: dismiss)
    }
}

// MARK: - Layout

/// Wrapping row for chips (genres, pills).
struct FlowRow: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat? = nil

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rowGap = lineSpacing ?? spacing
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + rowGap
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rowGap = lineSpacing ?? spacing
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        // Centre each item vertically within its row.
        var rows: [[(Subviews.Element, CGSize)]] = [[]]
        var rowWidth: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            // A pixel of slack: layout rounds bounds to the pixel grid, which must not re-wrap a row that fit when sized.
            if rowWidth > 0 && rowWidth + size.width > bounds.width + 1 {
                rows.append([])
                rowWidth = 0
            }
            rows[rows.count - 1].append((view, size))
            rowWidth += size.width + spacing
        }
        for row in rows {
            rowHeight = row.map { $0.1.height }.max() ?? 0
            x = bounds.minX
            for (view, size) in row {
                view.place(at: CGPoint(x: x, y: y + (rowHeight - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + rowGap
        }
    }
}

extension RailState {
    var label: String {
        switch self {
        case .owned: return "Downloaded"
        case .partial: return "Partial"
        case .wanted: return "Missing"
        case .downloading: return "Downloading"
        case .upgrading: return "Upgrading"
        case .upcoming: return "Upcoming"
        }
    }
}

/// The key/value cell of a meta grid (`ROOT FOLDER` / `/demo/tv`).
struct DetailMetaCell: View {
    let key: String
    let value: String
    var valueColor: Color = Theme.txt
    var trailingCheck = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(key.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Theme.dim)
            HStack(spacing: 5) {
                Text(value)
                    .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(valueColor)
                    .lineLimit(2)
                    .truncationMode(.middle)
                if trailingCheck {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(valueColor)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(Theme.panel2)
    }
}
