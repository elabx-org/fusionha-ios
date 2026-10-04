import SwiftUI
import FusionhaKit

// Small pieces shared by the Calendar views and the Account screen: the web's
// `sm` buttons, the edition rail, glyphs, the empty state and a toast.

// MARK: Colours

extension CalendarStatusKey {
    /// `lib/status.ts`: downloaded green, downloading cyan, missing amber, unaired blue.
    var color: Color {
        switch self {
        case .downloaded: return Theme.done
        case .downloading: return Theme.grab
        case .missing: return Theme.miss
        case .unaired: return Theme.unaired
        }
    }
}

extension MovieReleaseType {
    var color: Color {
        switch self {
        case .theatrical: return Theme.indigo
        case .digital: return Theme.cyan
        case .physical: return Theme.edition
        }
    }

    var symbol: String {
        switch self {
        case .theatrical: return "ticket"
        case .digital: return "icloud.and.arrow.down"
        case .physical: return "opticaldisc"
        }
    }
}

extension CalendarEntry {
    /// The month pill's accent strip: anime pink, movie purple, else the first edition's tier.
    var accent: Color {
        if isAnime { return Theme.anime }
        if isMovie { return Theme.edition }
        return editions.first?.tier.color ?? QualityTier.hd.color
    }

    /// The `accent` week card's tint (its first edition's tier).
    var accentTier: QualityTier { editions.first?.tier ?? .hd }
}

extension Text {
    /// The web's global `letter-spacing: -0.01em`.
    func webTracking(_ size: CGFloat) -> Text { tracking(-0.01 * size) }
}

// MARK: Buttons (`components/ui/Button`, size `sm`)

enum CalButtonVariant {
    case subtle, ghost, danger, primary
}

struct CalButtonStyle: ButtonStyle {
    var variant: CalButtonVariant = .subtle
    var fullWidth = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: variant == .primary ? .bold : .semibold))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, 11)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 30, maxHeight: 30)
            .background { background }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(border)
            }
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .opacity(isEnabled ? 1 : 0.5)
            .offset(y: configuration.isPressed ? 1 : 0)
    }

    private var foreground: Color {
        switch variant {
        case .subtle: return Theme.txt
        case .ghost: return Theme.mut
        case .danger: return Theme.danger
        case .primary: return Theme.bg
        }
    }

    private var border: Color {
        switch variant {
        case .subtle: return Theme.line
        case .ghost, .primary: return .clear
        case .danger: return Theme.danger.opacity(0.4)
        }
    }

    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        switch variant {
        case .subtle: shape.fill(Theme.panel)
        case .ghost, .danger: shape.fill(Color.clear)
        case .primary: shape.fill(Theme.fusion)
        }
    }
}

// MARK: Glyphs (the web's 24-unit stroke icons)

/// The web's line icons, drawn in a 24×24 box and stroked at 1.9.
struct LineGlyph: View {
    enum Kind {
        case movie, series, anime, feed
    }

    let kind: Kind
    var size: CGFloat = 13
    var lineWidth: CGFloat = 1.9

    var body: some View {
        GlyphShape(kind: kind)
            .stroke(style: StrokeStyle(lineWidth: lineWidth * size / 24, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }

    static func kind(for entry: CalendarEntry) -> Kind {
        entry.isAnime ? .anime : (entry.isMovie ? .movie : .series)
    }
}

private struct GlyphShape: Shape {
    let kind: LineGlyph.Kind

    func path(in rect: CGRect) -> Path {
        let s = rect.width / 24
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        var path = Path()
        func line(_ a: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat)) {
            path.move(to: p(a.0, a.1))
            path.addLine(to: p(b.0, b.1))
        }
        func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) {
            path.addRoundedRect(in: CGRect(x: rect.minX + x * s, y: rect.minY + y * s, width: w * s, height: h * s),
                                cornerSize: CGSize(width: r * s, height: r * s))
        }
        switch kind {
        case .movie:
            rrect(3, 4, 18, 16, 2)
            line((7.5, 4), (7.5, 20)); line((16.5, 4), (16.5, 20))
            line((3, 9.3), (7.5, 9.3)); line((3, 14.7), (7.5, 14.7))
            line((16.5, 9.3), (21, 9.3)); line((16.5, 14.7), (21, 14.7))
        case .series:
            rrect(3, 7, 18, 13, 2)
            path.move(to: p(8.5, 2.5)); path.addLine(to: p(12, 6)); path.addLine(to: p(15.5, 2.5))
        case .anime:
            path.move(to: p(3, 6))
            path.addCurve(to: p(21, 6), control1: p(5.8, 4.6), control2: p(18.2, 4.6))
            line((6.2, 5.1), (5.4, 20)); line((17.8, 5.1), (18.6, 20))
            line((4.5, 10.5), (19.5, 10.5)); line((12, 5.4), (12, 10.5))
        case .feed:
            rrect(3, 5, 18, 16, 2)
            line((8, 3), (8, 7)); line((16, 3), (16, 7))
            line((3, 11), (21, 11)); line((10.5, 16.5), (13.5, 16.5))
        }
        return path
    }
}

// MARK: Edition rail (`RailBar` / `CalendarRail`)

enum CalRailMeta: Hashable {
    case check
    case down
    case wanted
    case soon
    /// A season drop: `2/3`, plus a check when complete or ↓ while grabbing.
    case count(String, complete: Bool, grabbing: Bool)
}

struct CalRailModel: Hashable {
    let tier: QualityTier
    let color: Color
    let statusLabel: String
    /// 0…1 fill; striped tracks (wanted / unaired) have no fill.
    let fill: Double
    let striped: Bool
    let downloading: Bool
    let meta: CalRailMeta

    /// One edition of an entry, unaired-aware.
    init(entry: CalendarEntry, edition: CalendarEdition, now: Date) {
        let key = entry.statusKey(for: edition, now: now)
        tier = edition.tier
        color = key.color
        statusLabel = key.label
        switch key {
        case .downloaded: fill = 1; striped = false; downloading = false; meta = .check
        case .downloading: fill = 0.45; striped = false; downloading = true; meta = .down
        case .missing: fill = 0; striped = true; downloading = false; meta = .wanted
        case .unaired: fill = 0; striped = true; downloading = false; meta = .soon
        }
    }

    /// A season drop's per-tier aggregate.
    init(season: SeasonTierAggregate) {
        tier = season.tier
        let complete = season.done == season.total
        let key: CalendarStatusKey = complete ? .downloaded : (season.grabbing > 0 ? .downloading : .missing)
        color = key.color
        statusLabel = key.label
        let ratio = season.total > 0 ? Double(season.done) / Double(season.total) : 0
        fill = complete ? 1 : ratio
        striped = key == .missing
        downloading = key == .downloading
        meta = .count("\(season.done)/\(season.total)", complete: complete, grabbing: season.grabbing > 0)
    }
}

/// `[tier chip] [52pt bar] [meta]`. Agenda rows outline the chip; week cards don't.
struct CalRail: View {
    let rail: CalRailModel
    var outlinedTier = true
    var metaSize: CGFloat = 9

    var body: some View {
        HStack(spacing: 6) {
            Text(rail.tier.pill)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(0.3)
                .foregroundStyle(rail.tier.color)
                .padding(.horizontal, outlinedTier ? 4 : 0)
                .padding(.vertical, outlinedTier ? 1 : 0)
                .frame(minWidth: outlinedTier ? 22 : 0)
                .overlay {
                    if outlinedTier {
                        RoundedRectangle(cornerRadius: 4).strokeBorder(rail.tier.color.opacity(0.45))
                    }
                }
            CalRailBar(rail: rail)
                .frame(width: 52, height: 5)
            meta
                .font(.system(size: metaSize, weight: .bold, design: .monospaced))
                .foregroundStyle(rail.color)
                .lineLimit(1)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rail.tier.chipLabel) \(rail.statusLabel)")
    }

    @ViewBuilder
    private var meta: some View {
        switch rail.meta {
        case .check:
            Image(systemName: "checkmark").font(.system(size: metaSize + 1, weight: .heavy))
        case .down:
            Text("↓")
        case .wanted:
            Text("wanted")
        case .soon:
            HStack(spacing: 2) {
                Image(systemName: "clock").font(.system(size: 9, weight: .bold))
                Text("soon")
            }
        case .count(let text, let complete, let grabbing):
            HStack(spacing: 2) {
                Text(text)
                if complete {
                    Image(systemName: "checkmark").font(.system(size: metaSize + 1, weight: .heavy))
                } else if grabbing {
                    Text("↓")
                }
            }
        }
    }
}

struct CalRailBar: View {
    let rail: CalRailModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.calMotionOff) private var motionOff
    @State private var sweep = false
    /// `.rfill` grows to its width over 0.9s (REVEAL_EASE).
    @State private var grown = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                if rail.striped {
                    Canvas { context, size in
                        var x: CGFloat = 0
                        while x < size.width {
                            context.fill(Path(CGRect(x: x, y: 0, width: 5, height: size.height)),
                                         with: .color(rail.color.opacity(0.3)))
                            x += 10
                        }
                    }
                } else {
                    Rectangle().fill(Color.white.opacity(0.08))
                    Rectangle().fill(rail.color).frame(width: w * (grown || reduceMotion || motionOff ? rail.fill : 0))
                        .clipShape(Capsule())
                }
                if rail.downloading && !reduceMotion && !motionOff {
                    LinearGradient(colors: [.clear, .white.opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: w * 0.38)
                        .offset(x: sweep ? w : -w * 0.4)
                        .onAppear {
                            withAnimation(.timingCurve(0.52, 0.01, 0.16, 1, duration: 1.5).repeatForever(autoreverses: false)) {
                                sweep = true
                            }
                        }
                }
            }
        }
        .clipShape(Capsule())
        .onAppear {
            guard !grown else { return }
            if reduceMotion || motionOff { grown = true } else {
                withAnimation(CalMotion.reveal(duration: 0.9)) { grown = true }
            }
        }
    }
}

// MARK: Empty state (`components/ui/EmptyState`)

struct CalEmptyState: View {
    let message: String
    var quip: String?

    var body: some View {
        VStack(spacing: 6) {
            Text(message)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.mut)
                .lineSpacing(13.5 * 0.6 - 3)
            if let quip {
                (Text("— ").foregroundColor(Color.white.opacity(0.08)) + Text(quip).italic().foregroundColor(Theme.dim))
                    .font(.system(size: 13.5))
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
            .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
    }
}

// MARK: Toast

struct CalToast: Equatable, Identifiable {
    let id = UUID()
    var title: String?
    let message: String
    var isError = false
}

/// A bottom toast, like the web's `useToast`. Glass, since it is chrome.
struct CalToastHost: ViewModifier {
    @Binding var toast: CalToast?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let toast {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: toast.isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(toast.isError ? Theme.danger : Theme.done)
                    VStack(alignment: .leading, spacing: 2) {
                        if let title = toast.title {
                            Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
                        }
                        Text(toast.message).font(.system(size: 13)).foregroundStyle(toast.title == nil ? Theme.txt : Theme.mut)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(toast.id)
                .task(id: toast.id) {
                    try? await Task.sleep(for: .seconds(3.2))
                    withAnimation(.smooth) { self.toast = nil }
                }
                .onTapGesture { withAnimation(.smooth) { self.toast = nil } }
            }
        }
        .animation(.smooth(duration: 0.25), value: toast)
    }
}

extension View {
    func calToast(_ toast: Binding<CalToast?>) -> some View {
        modifier(CalToastHost(toast: toast))
    }
}

// MARK: Motion (web `components/motion/Reveal` + the Calendar keyframes)

/// Motion is off under the system Reduce Motion setting OR the server's
/// `animations_enabled = false` (the web's ReduceMotionProvider "always" mode).
private struct CalMotionOffKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var calMotionOff: Bool {
        get { self[CalMotionOffKey.self] }
        set { self[CalMotionOffKey.self] = newValue }
    }
}

enum CalMotion {
    /// framer-motion `REVEAL_EASE` [0.52, 0.01, 0.16, 1].
    static func reveal(duration: Double = 0.5) -> Animation {
        .timingCurve(0.52, 0.01, 0.16, 1, duration: duration)
    }
}

/// `Reveal` / `RevealItem`: fades up from 16pt with a per-item stagger, on mount.
/// Instant when motion is off.
private struct CalReveal: ViewModifier {
    let index: Int
    let stagger: Double
    var y: CGFloat = 16
    @Environment(\.calMotionOff) private var motionOff
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        let off = motionOff || reduceMotion
        content
            .opacity(off || shown ? 1 : 0)
            .offset(y: off || shown ? 0 : y)
            .onAppear {
                guard !off, !shown else { return }
                // Long lists cap the stagger so late items don't wait seconds.
                let delay = Double(min(index, 40)) * stagger
                withAnimation(CalMotion.reveal().delay(delay)) { shown = true }
            }
    }
}

extension View {
    func calReveal(_ index: Int, stagger: Double, y: CGFloat = 16) -> some View {
        modifier(CalReveal(index: index, stagger: stagger, y: y))
    }
}

/// `calPulse`: a live grab's background breathes between mut 10 % and grab 12 % (1.8s).
private struct CalLivePulse: ViewModifier {
    let live: Bool
    let shape: RoundedRectangle
    var base: Color = Theme.mut.opacity(0.10)
    @Environment(\.calMotionOff) private var motionOff
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    func body(content: Content) -> some View {
        let on = live && !motionOff && !reduceMotion
        content
            .background(on && pulse ? Theme.grab.opacity(0.12) : base, in: shape)
            .onAppear {
                guard on else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
            }
    }
}

extension View {
    func calLivePulse(_ live: Bool, shape: RoundedRectangle, base: Color = Theme.mut.opacity(0.10)) -> some View {
        modifier(CalLivePulse(live: live, shape: shape, base: base))
    }
}
