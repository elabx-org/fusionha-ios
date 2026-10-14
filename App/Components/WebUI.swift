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
    /// Title above the subtitle (the redesign's layout, now the default).
    var stacked = true
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

    /// The redesign's page title: the display face, 56pt, tight.
    private var titleText: some View {
        Text(title)
            .pageTitle(56)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    @ViewBuilder
    private var subtitleText: some View {
        if let subtitle {
            Text(subtitle)
                .font(.system(size: 15))
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
    /// Filters (All / HD / 4K, Recency): a cream wash marks the selection.
    case accent
    /// Page tabs, Add kind tabs: the same, with heavier text off.
    case plain
}

/// The web's SegGroup in the redesign: segments on a glass capsule, the
/// selection a sliding cream wash (status colours never mark a control).
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
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selected ? Theme.txt : Theme.mut)
                        .lineLimit(1)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 6)
                        .frame(maxWidth: fill ? .infinity : nil, minHeight: 30)
                        .background {
                            if selected {
                                selectedBackground.matchedGeometryEffect(id: "segment", in: indicator)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .glassEffect(.regular.interactive(), in: Capsule())
        .sensoryFeedback(.selection, trigger: selection)
    }

    private var selectedBackground: some View {
        Capsule().fill(Theme.txt.opacity(0.16))
    }
}

/// The web's kind chip (`.kchip`) as a glass filter chip: swatch, count and
/// label; the selected chip gets the cream wash. Also used for Wanted tabs and the
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
                Text(label).font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(selected ? Theme.txt : Theme.mut)
                if let count, topAccent != nil {
                    Text("\(count)").font(.system(size: 12.5, weight: .bold).monospacedDigit()).foregroundStyle(Theme.mut)
                }
            }
            .lineLimit(1)
            .padding(.leading, 9)
            .padding(.trailing, 11)
            .padding(.vertical, 7)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassControl(on: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
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
        // Naive server timestamps are UTC (ServerTime).
        let date = ServerTime.parse(iso)
        if let date { parsed.setObject(date as NSDate, forKey: iso as NSString) }
        return date
    }

    private static let parsed: NSCache<NSString, NSDate> = {
        let c = NSCache<NSString, NSDate>()
        c.countLimit = 20_000
        return c
    }()

    static func relative(_ iso: String?) -> String {
        guard let date = timestamp(iso) else { return "" }
        return date.formatted(.relative(presentation: .named))
    }

    static func shortDate(_ iso: String?) -> String {
        guard let date = day(iso) else { return "" }
        return date.formatted(.dateTime.day().month(.abbreviated).year())
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
