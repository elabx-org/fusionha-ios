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

/// Page title + muted subtitle on one line, like the web's page headers.
struct PageHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var stacked = false
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: stacked ? .top : .firstTextBaseline, spacing: 12) {
            if stacked {
                VStack(alignment: .leading, spacing: 6) {
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
            .font(.system(size: 28, weight: .heavy))
            .tracking(-0.6)
            .foregroundStyle(Theme.txt)
            .lineLimit(1)
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

/// The dashed "nothing here" box the web uses for empty and error states.
struct EmptyBox: View {
    let message: String
    var systemImage: String?

    var body: some View {
        VStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage).font(.title2).foregroundStyle(Theme.dim)
            }
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(Theme.mut)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous)
                .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
    }
}

// MARK: Segmented pills

enum SegmentStyle {
    /// Indigo-tinted selection with a cyan text (filters: All / HD / 4K, kinds).
    case accent
    /// Raised dark selection (page tabs: Queue / History / Blocklist).
    case plain
}

/// The web's pill segmented control: segments in a bordered dark track.
struct SegmentedPills<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value
    var style: SegmentStyle = .accent
    var fill = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { index in
                let value = options[index].0
                let label = options[index].1
                let selected = value == selection
                Button {
                    withAnimation(.snappy(duration: 0.25)) { selection = value }
                } label: {
                    Text(label)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(selected ? selectedText : Theme.mut)
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: fill ? .infinity : nil, minHeight: 36)
                        .background {
                            if selected { selectedBackground }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .panel(Theme.panel2, radius: 12)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private var selectedText: Color {
        style == .accent ? Color(hex: 0xA5F3FC) : Theme.txt
    }

    @ViewBuilder
    private var selectedBackground: some View {
        switch style {
        case .accent:
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Theme.indigo.opacity(0.26))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Theme.indigo.opacity(0.7)))
        case .plain:
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Theme.bg.opacity(0.7))
        }
    }
}

/// A rounded chip with a coloured dot, an optional count and a label
/// (library kinds, Wanted tabs, calendar kinds).
struct DotChip: View {
    let label: String
    var count: Int?
    var dot: Color?
    var selected = false
    var topAccent: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let dot {
                    Circle().fill(dot).frame(width: 8, height: 8)
                }
                if let count, topAccent == nil {
                    Text("\(count)").font(.system(size: 14, weight: .heavy)).foregroundStyle(Theme.txt)
                }
                Text(label).font(.system(size: 14, weight: .bold))
                    .foregroundStyle(selected ? Theme.txt : Theme.mut)
                if let count, topAccent != nil {
                    Text("\(count)").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.mut)
                }
            }
            .lineLimit(1)
            .padding(.horizontal, 13)
            .frame(minHeight: 34)
            .background(selected ? (topAccent ?? Theme.cyan).opacity(0.10) : Theme.panel,
                        in: Capsule())
            .overlay(Capsule().strokeBorder(selected ? (topAccent ?? Theme.cyan).opacity(0.6) : Theme.line))
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

/// One edition's `[tier pill] [fill bar] [meta]` row from the web's poster card.
struct CoverageRailView: View {
    let edition: Edition
    let isSeries: Bool

    var body: some View {
        let rail = edition.rail(isSeries: isSeries)
        let color = rail.attention ? (rail.deadLinkOnly ? Theme.stuck : Theme.miss) : rail.state.color
        HStack(spacing: 8) {
            TierPill(tier: edition.tier)
            RailBar(progress: rail.progress, color: color, state: rail.state)
            meta(rail, color: color)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(edition.tier.chipLabel), \(rail.state.rawValue)\(rail.fraction.map { ", \($0)" } ?? "")")
    }

    @ViewBuilder
    private func meta(_ rail: Rail, color: Color) -> some View {
        if rail.attention {
            Image(systemName: rail.deadLinkOnly ? "link" : "exclamationmark.triangle.fill")
        } else {
            switch rail.state {
            case .owned:
                HStack(spacing: 3) {
                    if let f = rail.fraction { Text(f) }
                    Image(systemName: "checkmark").fontWeight(.heavy)
                }
            case .downloading:
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.to.line").fontWeight(.bold)
                    if let f = rail.fraction { Text(f) }
                }
            case .upgrading:
                HStack(spacing: 3) {
                    if let f = rail.fraction { Text(f) }
                    Image(systemName: "arrow.up").fontWeight(.bold)
                }
            case .upcoming:
                Image(systemName: "clock")
            case .partial, .wanted:
                Text(rail.fraction ?? "Wanted")
            }
        }
    }
}

/// The 6pt rounded rail track with its status fill.
struct RailBar: View {
    let progress: Int
    let color: Color
    var state: RailState = .owned

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.07))
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(progress) / 100)
                    .shadow(color: state == .owned ? color.opacity(0.5) : .clear, radius: 3)
            }
        }
        .frame(height: 6)
    }
}

// MARK: Misc

/// The kind glyph on poster meta lines (film / tv).
struct KindGlyph: View {
    let kind: MediaKind
    var body: some View {
        Image(systemName: kind == .movie ? "film" : "tv")
            .font(.system(size: 11, weight: .medium))
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
    static func bytes(_ value: Double?) -> String {
        guard let value, value > 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file)
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
        guard let iso else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: iso) { return d }
        // The server sends naive UTC timestamps (no zone): treat them as UTC.
        let p = DateFormatter()
        p.locale = Locale(identifier: "en_US_POSIX")
        p.timeZone = TimeZone(identifier: "UTC")
        for format in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss"] {
            p.dateFormat = format
            if let d = p.date(from: iso) { return d }
        }
        return nil
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
