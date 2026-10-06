import SwiftUI
import FusionhaKit

// SwiftUI counterparts of the web app's shared UI pieces, so screens read like
// the web: dark panels with hairline borders, pill segments, dot chips, tier
// pills and coverage rails. Native Liquid Glass is reserved for system chrome
// (tab bar, sheets, menus).

// MARK: Surfaces

extension View {
    /// A web `panel`: dark fill, hairline border, rounded corners.
    func panel(_ fill: Color = Theme.panel, radius: CGFloat = Theme.radiusLg) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.line))
    }

    /// The page background used by every screen.
    func webBackground() -> some View {
        background(Theme.bg.ignoresSafeArea())
    }
}

/// Page title + muted stats on one baseline (the web's `.head`: h1 21/700,
/// letter-spacing -0.02em; stats 13/500 `--mut`; gap 12).
struct PageHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var stacked = false
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: stacked ? .top : .firstTextBaseline, spacing: 12) {
            if stacked {
                VStack(alignment: .leading, spacing: 4) {
                    titleText
                    subtitleText
                }
            } else {
                titleText
                subtitleText
            }
            Spacer(minLength: 0)
            trailing
        }
    }

    private var titleText: some View {
        Text(title)
            .font(.system(size: 21, weight: .bold))
            .tracking(-0.42)
            .foregroundStyle(Theme.txt)
            .lineLimit(1)
    }

    @ViewBuilder
    private var subtitleText: some View {
        if let subtitle {
            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.mut)
                .lineLimit(stacked ? 2 : 1)
        }
    }
}

extension PageHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, stacked: Bool = false) {
        self.init(title: title, subtitle: subtitle, stacked: stacked) { EmptyView() }
    }
}

/// Small uppercase, letter-spaced label (`WANTED TITLES`, `QUALITY EDITIONS`).
struct EyebrowLabel: View {
    let text: String
    var color: Color = Theme.dim

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(1.4)
            .foregroundStyle(color)
    }
}

/// The web's shared state box (loading/empty/error/no-match): `--card` fill,
/// hairline border, radius 14, padding 46/34, centred 14px `--mut` copy.
struct EmptyBox: View {
    let message: String
    var systemImage: String?

    var body: some View {
        VStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 20)).foregroundStyle(Theme.dim)
            }
            Text(message)
                .font(.system(size: 14))
                .lineSpacing(14 * 0.55 - 3)
                .foregroundStyle(Theme.mut)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 46)
        .padding(.horizontal, 34)
        .panel(Theme.card, radius: Theme.radiusLg)
    }
}

// MARK: Segmented pills

enum SegmentStyle {
    /// The web's SegGroup: indigo-tinted selection with cyan-mixed text
    /// (filters: All / HD / 4K, Recency).
    case accent
    /// Neutral raised selection (`--card` + shadow): page tabs, Add kind tabs.
    case plain
}

/// The web's SegGroup: segments in a bordered `--panel` track (padding 3,
/// radius 10); buttons 12.5/600 `--mut`, padding 6/13, radius 7.
struct SegmentedPills<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value
    var style: SegmentStyle = .accent
    var fill = false
    @Namespace private var indicator
    @Environment(\.motionEnabled) private var motion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let value = options[index].0
                let label = options[index].1
                let selected = value == selection
                Button {
                    withAnimation(motion ? Motion.indicator : nil) { selection = value }
                } label: {
                    Text(label)
                        .font(.system(size: 12.5, weight: selected && style == .accent ? .heavy : .semibold))
                        .foregroundStyle(selected ? selectedText : Theme.mut)
                        .lineLimit(1)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 6)
                        .frame(maxWidth: fill ? .infinity : nil, minHeight: 30)
                        .background {
                            if selected {
                                selectedBackground.matchedGeometryEffect(id: "segment", in: indicator)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .panel(style == .plain ? Theme.panel2 : Theme.panel, radius: style == .plain ? 11 : 10)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private var selectedText: Color {
        style == .accent ? Theme.segActiveText : Theme.txt
    }

    @ViewBuilder
    private var selectedBackground: some View {
        switch style {
        case .accent:
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Theme.indigo.opacity(0.14))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Theme.indigo.opacity(0.55)))
        case .plain:
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.card)
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        }
    }
}

/// The web's kind chip (`.kchip`): swatch, count and label in a hairline pill
/// that tints with its colour when active. Also used for Wanted tabs and the
/// calendar kinds.
struct DotChip: View {
    let label: String
    var count: Int?
    var dot: Color?
    var selected = false
    var topAccent: Color?
    var swatch: AnyShapeStyle? = nil
    let action: () -> Void

    var body: some View {
        let tint = topAccent ?? dot ?? Theme.cyan
        Button(action: action) {
            HStack(spacing: 7) {
                if let swatch {
                    RoundedRectangle(cornerRadius: 3).fill(swatch).frame(width: 8, height: 8)
                } else if let dot {
                    RoundedRectangle(cornerRadius: 3).fill(dot).frame(width: 8, height: 8)
                }
                if let count, topAccent == nil {
                    Text("\(count)").font(.system(size: 12.5, weight: .bold).monospacedDigit()).foregroundStyle(Theme.txt)
                }
                Text(label).font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(selected && topAccent != nil ? Theme.txt : Theme.mut)
                if let count, topAccent != nil {
                    Text("\(count)").font(.system(size: 12.5, weight: .bold).monospacedDigit()).foregroundStyle(Theme.mut)
                }
            }
            .lineLimit(1)
            .padding(.leading, 9)
            .padding(.trailing, 11)
            .padding(.vertical, 5)
            .background(selected ? tint.opacity(0.14) : .clear, in: Capsule())
            .overlay(Capsule().strokeBorder(selected ? tint.opacity(0.55) : Theme.line))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: Search

/// The web's search field: dark rounded box, magnifier, 16pt text.
struct WebSearchField: View {
    let placeholder: String
    @Binding var text: String
    var onSubmit: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.mut)
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Theme.dim))
                .font(.system(size: 16))
                .foregroundStyle(Theme.txt)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit(onSubmit)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.mut)
                        .frame(width: 26, height: 26)
                        .background(Theme.txt.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .panel(Theme.panel2, radius: 12)
    }
}

// MARK: Tier pill + coverage rail

/// `HD` / `4K` in a mono outlined pill (CoverageRail `.tier`).
struct TierPill: View {
    let tier: QualityTier
    var large = false

    var body: some View {
        Text(large ? tier.chipLabel : tier.pill)
            .font(.system(size: large ? 12 : 9.5, weight: .heavy, design: .monospaced))
            .tracking(0.3)
            .foregroundStyle(tier.color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .frame(minWidth: 26)
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(tier.color.opacity(0.45)))
    }
}

/// The two-tier "HD·4K" pill of a consolidated rail.
struct TierComboPill: View {
    var body: some View {
        HStack(spacing: 3) {
            Text("HD").foregroundStyle(Theme.edition)
            Text("·").foregroundStyle(Theme.mut.opacity(0.7))
            Text("4K").foregroundStyle(Theme.grab)
        }
        .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
        .tracking(0.3)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .frame(minWidth: 26)
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color(hex: 0x64B6F3).opacity(0.9)))
    }
}

/// `library_rail_style` (Settings → Library): the full rail, the bar only, or a
/// trailing dot.
enum RailStyle: String, CaseIterable, Sendable {
    case current, fill, dot

    var label: String {
        switch self {
        case .current: return "Current"
        case .fill: return "Fill only"
        case .dot: return "Trailing dot"
        }
    }

    var hint: String {
        switch self {
        case .current: return "Tier, bar and a status glyph or count."
        case .fill: return "Just the bar, with the size or count."
        case .dot: return "The bar with a coloured status dot."
        }
    }
}

private struct RailStyleKey: EnvironmentKey {
    static let defaultValue: RailStyle = .current
}

private struct RailConsolidateKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var railStyle: RailStyle {
        get { self[RailStyleKey.self] }
        set { self[RailStyleKey.self] = newValue }
    }
    var railConsolidate: Bool {
        get { self[RailConsolidateKey.self] }
        set { self[RailConsolidateKey.self] = newValue }
    }
}

/// One edition's `[tier pill] [fill bar] [meta]` row (CoverageRail.tsx).
struct CoverageRailView: View {
    let edition: Edition
    let isSeries: Bool
    var itemUpcoming = false
    var itemUpcomingDate: String? = nil
    var inline = false

    var body: some View {
        RailRowView(rail: edition.rail(isSeries: isSeries, itemUpcoming: itemUpcoming, itemUpcomingDate: itemUpcomingDate),
                    tier: edition.tier, size: edition.size ?? 0, inline: inline)
    }
}

/// Every rail of a title, consolidating complete HD + 4K pairs into one
/// "HD·4K" rail when the library setting asks for it (rail-consolidate.ts).
struct CoverageRails: View {
    let item: MediaItem
    var inline = false
    var spacing: CGFloat = 4
    @Environment(\.railConsolidate) private var consolidate

    var body: some View {
        let rails = item.rails
        let units = Self.units(item: item, rails: rails, consolidate: consolidate)
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(units.indices, id: \.self) { i in
                let unit = units[i]
                if let mate = unit.mate {
                    RailRowView(rail: combo(rails[unit.index], rails[mate]), tier: .hd,
                                size: (item.editions[unit.index].size ?? 0) + (item.editions[mate].size ?? 0),
                                combo: true, inline: inline)
                } else {
                    RailRowView(rail: rails[unit.index], tier: item.editions[unit.index].tier,
                                size: item.editions[unit.index].size ?? 0, inline: inline)
                }
            }
        }
    }

    private func combo(_ a: Rail, _ b: Rail) -> Rail {
        let fraction: String?
        if item.kind == .series {
            let haves = item.editions.map { $0.have ?? 0 }.reduce(0, +)
            let totals = item.editions.map { $0.total ?? 0 }.reduce(0, +)
            fraction = "\(haves)/\(totals)"
        } else {
            fraction = nil
        }
        return Rail(state: .owned, progress: 100, fraction: fraction, attention: false, deadLinkOnly: false)
    }

    struct Unit { let index: Int; let mate: Int? }

    static func units(item: MediaItem, rails: [Rail], consolidate: Bool) -> [Unit] {
        guard consolidate else { return rails.indices.map { Unit(index: $0, mate: nil) } }
        func complete(_ i: Int) -> Bool { rails[i].state == .owned && !rails[i].attention }
        var consumed = Set<Int>()
        var units: [Unit] = []
        for i in rails.indices where !consumed.contains(i) {
            if complete(i) {
                let ed = item.editions[i]
                let mate = rails.indices.first { j in
                    j != i && !consumed.contains(j) && item.editions[j].tier != ed.tier
                        && item.editions[j].movieEdition == ed.movieEdition && complete(j)
                }
                if let mate {
                    consumed.insert(i)
                    consumed.insert(mate)
                    let hdFirst = ed.tier == .hd
                    units.append(Unit(index: hdFirst ? i : mate, mate: hdFirst ? mate : i))
                    continue
                }
            }
            consumed.insert(i)
            units.append(Unit(index: i, mate: nil))
        }
        return units
    }
}

/// A rail from a precomputed `Rail` (grid auto 1fr auto, gap 8; inline auto 54 auto, gap 7).
struct RailRowView: View {
    let rail: Rail
    let tier: QualityTier
    var size: Double = 0
    var combo = false
    var inline = false
    @Environment(\.railStyle) private var style

    var body: some View {
        let color = rail.attention ? (rail.deadLinkOnly ? Theme.stuck : Theme.miss) : rail.state.color
        HStack(spacing: inline ? 7 : 8) {
            if combo { TierComboPill() } else { TierPill(tier: tier) }
            RailBar(progress: rail.progress, color: color, state: rail.state, attention: rail.attention, combo: combo)
                .frame(width: inline ? 54 : nil)
            meta(color: color)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(rail.upcomingEstimated ? Theme.mut : color)
                .lineLimit(1)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(combo ? "HD and 4K" : tier.chipLabel), \(rail.state.rawValue)\(rail.fraction.map { ", \($0)" } ?? "")")
    }

    @ViewBuilder
    private func meta(color: Color) -> some View {
        if rail.attention {
            Image(systemName: rail.deadLinkOnly ? "link" : "exclamationmark.triangle")
                .font(.system(size: 10, weight: .semibold))
        } else {
            switch rail.state {
            case .upcoming:
                HStack(spacing: 4) {
                    Image(systemName: rail.upcomingStage == "digital" ? "tv"
                          : rail.upcomingStage == "physical" ? "opticaldisc" : "clock")
                        .font(.system(size: 10, weight: .semibold))
                    if let date = rail.upcomingDate {
                        Text((rail.upcomingEstimated ? "~" : "") + Format.releaseDate(date))
                    } else {
                        Text("Upcoming")
                    }
                }
            case .upgrading:
                HStack(spacing: 4) {
                    if let f = rail.fraction { Text(f) }
                    Image(systemName: "arrow.up").font(.system(size: 10, weight: .bold))
                }
            case .downloading:
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.to.line").font(.system(size: 10, weight: .bold))
                    if style == .current {
                        if let f = rail.fraction { Text(f) }
                    } else {
                        Text("\(rail.progress)%")
                    }
                }
            case .owned:
                switch style {
                case .fill: Text(rail.fraction ?? Format.bytes(size))
                case .dot: Circle().fill(color).frame(width: 8, height: 8)
                case .current:
                    HStack(spacing: 4) {
                        if let f = rail.fraction { Text(f) }
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy))
                    }
                }
            case .partial, .wanted:
                switch style {
                case .fill: if let f = rail.fraction { Text(f) }
                case .dot: Circle().fill(color).frame(width: 8, height: 8)
                case .current: Text(rail.fraction ?? "Wanted")
                }
            }
        }
    }
}

/// The 6pt rounded rail track with its status fill: diagonal blue stripes for
/// upcoming, a cyan gradient with a white sweep while downloading.
struct RailBar: View {
    let progress: Int
    let color: Color
    var state: RailState = .owned
    var attention = false
    var combo = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                if state == .upcoming && !attention {
                    Stripes(color: Theme.unaired.opacity(0.22))
                } else {
                    Capsule().fill(Color.white.opacity(0.07))
                }
                fill.frame(width: geo.size.width * CGFloat(progress) / 100)
                if state == .downloading && !attention && !reduceMotion {
                    Sweep(width: geo.size.width)
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 6)
    }

    @ViewBuilder
    private var fill: some View {
        if combo {
            Capsule().fill(LinearGradient(colors: [Theme.edition, Theme.grab], startPoint: .leading, endPoint: .trailing))
        } else if state == .downloading && !attention {
            Capsule().fill(LinearGradient(colors: [Theme.grab, Theme.grab.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
        } else {
            Capsule().fill(color)
        }
    }
}

/// `repeating-linear-gradient(90deg, c 0 6px, transparent 6px 12px)`.
private struct Stripes: View {
    let color: Color
    var body: some View {
        Canvas { context, size in
            var x: CGFloat = 0
            while x < size.width {
                context.fill(Path(CGRect(x: x, y: 0, width: 6, height: size.height)), with: .color(color))
                x += 12
            }
        }
    }
}

/// The 1.5s white sweep across a downloading bar (render-loop driven, see `RepeatForever`).
private struct Sweep: View {
    let width: CGFloat
    var body: some View {
        RepeatForever(animation: .timingCurve(0.2, 0.6, 0.35, 1, duration: 1.5).repeatForever(autoreverses: false)) { on in
            LinearGradient(colors: [.clear, .white.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: width * 0.38)
                .offset(x: -width * 0.4 + (on ? width * 1.4 : 0))
        }
        .allowsHitTesting(false)
    }
}

// MARK: Misc

/// The kind glyph on poster meta lines (film / tv).
struct KindGlyph: View {
    let kind: MediaKind
    var body: some View {
        Image(systemName: kind == .movie ? "film" : "tv")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.mut)
    }
}

/// The pink `Anime` capsule.
struct AnimeChip: View {
    var body: some View {
        Text("Anime")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Theme.anime)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Theme.anime.opacity(0.16), in: Capsule())
    }
}

/// A web icon button: a dark rounded square with a hairline border.
struct SquareIconButton: View {
    let systemImage: String
    var label: String
    var size: CGFloat = 38
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.txt)
                .frame(width: size, height: size)
                .panel(Theme.panel, radius: 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

enum Format {
    /// The web's `formatBytes`: TB/GB to 1dp, else whole MB; "—" for nothing.
    static func bytes(_ value: Double?) -> String {
        guard let value, value > 0, value.isFinite else { return "—" }
        let gb = value / 1_073_741_824
        if gb >= 1024 { return String(format: "%.1f TB", gb / 1024) }
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        return "\(max(1, Int((value / 1_048_576).rounded()))) MB"
    }

    /// `formatReleaseDate`: `2026-11-03` → `3 Nov 2026`.
    static func releaseDate(_ iso: String) -> String {
        let parts = iso.prefix(10).split(separator: "-")
        guard parts.count == 3, let m = Int(parts[1]), (1...12).contains(m), let d = Int(parts[2]) else { return iso }
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return "\(d) \(months[m - 1]) \(parts[0])"
    }

    private static let isoDay: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func day(_ iso: String?) -> Date? {
        guard let iso else { return nil }
        return isoDay.date(from: String(iso.prefix(10)))
    }

    static func timestamp(_ iso: String?) -> Date? {
        guard let iso, !iso.isEmpty else { return nil }
        // Lists parse the same strings over and over (sorting, relative times),
        // and building formatters is slow: parse each string once.
        if let hit = parsed.object(forKey: iso as NSString) { return hit as Date }
        var date = isoFractional.date(from: iso) ?? isoPlain.date(from: iso)
        if date == nil {
            // The server sends naive UTC timestamps (no zone): treat them as UTC.
            for f in naiveUTC { if let d = f.date(from: iso) { date = d; break } }
        }
        if let date { parsed.setObject(date as NSDate, forKey: iso as NSString) }
        return date
    }

    private static let parsed: NSCache<NSString, NSDate> = {
        let c = NSCache<NSString, NSDate>()
        c.countLimit = 20_000
        return c
    }()

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let naiveUTC: [DateFormatter] = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX", "yyyy-MM-dd'T'HH:mm:ssXXXXX", "yyyy-MM-dd HH:mm:ss.SSSSSS", "yyyy-MM-dd HH:mm:ss",
    ].map { format in
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = format
        return f
    }

    static func relative(_ iso: String?) -> String {
        guard let date = timestamp(iso) else { return "" }
        return date.formatted(.relative(presentation: .named))
    }

    static func shortDate(_ iso: String?) -> String {
        guard let date = day(iso) else { return "" }
        return date.formatted(.dateTime.day().month(.abbreviated).year())
    }
}

// MARK: Toasts (components/ui/Toast)

enum ToastVariant: Sendable {
    case success, error, warning, info

    var color: Color {
        switch self {
        case .success: return Theme.done
        case .error: return Theme.danger
        case .warning: return Theme.miss
        case .info: return Theme.grab
        }
    }

    var symbol: String {
        switch self {
        case .success: return "checkmark"
        case .error: return "exclamationmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .info: return "info.circle"
        }
    }
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let message: String
    var title: String?
    var variant: ToastVariant = .success
    var duration: Double = 4

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool { lhs.id == rhs.id }
}

/// The toast viewport: stacked, centred cards above the tab bar. Each card is
/// `icon | body | dismiss` on a translucent panel washed with its variant
/// colour, with a 2.5pt timer bar draining over its duration.
struct ToastHost: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 10) {
            ForEach(model.toasts) { toast in
                ToastCard(toast: toast) { model.dismissToast(toast.id) }
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 14)))
            }
        }
        .frame(maxWidth: 420)
        .padding(.horizontal, 16)
        .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.2), value: model.toasts)
    }
}

private struct ToastCard: View {
    let toast: ToastMessage
    let dismiss: () -> Void
    @State private var drained = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let vc = toast.variant.color
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: toast.variant.symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(vc)
                .frame(width: 30, height: 30)
                .background(vc.opacity(0.15), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                if let title = toast.title {
                    Text(title).font(.system(size: 13.5, weight: .bold)).foregroundStyle(Theme.txt)
                    Text(toast.message).font(.system(size: 13)).foregroundStyle(Theme.mut)
                } else {
                    Text(toast.message).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.txt)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.mut)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.top, 13)
        .padding(.trailing, 13)
        .padding(.bottom, 15)
        .padding(.leading, 15)
        .background {
            ZStack(alignment: .leading) {
                Rectangle().fill(.ultraThinMaterial)
                Theme.panel.opacity(0.92)
                LinearGradient(colors: [vc.opacity(0.16), .clear], startPoint: .leading, endPoint: .trailing)
            }
        }
        .overlay(alignment: .bottomLeading) {
            GeometryReader { geo in
                Rectangle().fill(vc.opacity(0.55))
                    .frame(width: drained ? 0 : geo.size.width, height: 2.5)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.line))
        .shadow(color: .black.opacity(0.55), radius: 22, y: 18)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: toast.duration)) { drained = true }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: Hide-on-scroll chrome

extension View {
    /// The web hides the top bar (and the FAB with the nav) while scrolling
    /// down past 90pt, and brings them back on any upward scroll. Apply to a
    /// tab's ScrollView.
    func hidesChromeOnScroll(_ model: AppModel) -> some View {
        onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top
        } action: { old, new in
            let delta = new - old
            if new <= 90 {
                if model.chromeHidden { model.chromeHidden = false }
            } else if delta > 4 {
                if !model.chromeHidden { model.chromeHidden = true }
            } else if delta < -4 {
                if model.chromeHidden { model.chromeHidden = false }
            }
        }
    }
}
