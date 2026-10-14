import SwiftUI
import FusionhaKit

/// fusionha's design tokens, shared by the app and widgets.
///
/// The redesign (`docs/design/redesign/DIRECTION.md`): posters as lit objects
/// on a shelf, a quiet ground, one house light for chrome and primary actions,
/// and every saturated hue left to status (the web's `status.ts`). The ground,
/// text and accent come from the palette chosen in Settings › Appearance
/// (`AppPalette`); Aurora, the web app's own, is the main one.
enum Theme {
    /// The active palette's colours (Settings › Appearance). Reading one
    /// registers the view with `PaletteStore`, so it redraws on a switch.
    static var palette: PaletteTokens { PaletteStore.shared.active.tokens }
    static var isLight: Bool { palette.isLight }

    // Ground, shelf objects and ink.
    static var bg: Color { Color(hex: palette.bg) }
    static var panel: Color { Color(hex: palette.panel) }
    static var panel2: Color { Color(hex: palette.panel2) }
    static var card: Color { Color(hex: palette.panel) }
    static var line: Color { Color(hex: palette.line).opacity(palette.lineOpacity) }
    static var txt: Color { Color(hex: palette.txt) }
    static var mut: Color { Color(hex: palette.mut) }
    static var dim: Color { Color(hex: palette.dim) }
    /// Text on the primary (`fusion`).
    static var onPrimary: Color { Color(hex: palette.onPrimary) }
    /// Text and ticks on a fill of the accent (`indigo` / `i1`).
    static var onAccent: Color { Color(hex: palette.onAccent) }
    /// The house light: the selected chip and today's date are filled with it.
    static var ink: Color { txt }
    /// Text on an `ink` (text-coloured) fill: the ground colour.
    static var onInk: Color { bg }

    static let kindMovie = Color(hex: 0x38BDF8)
    static let kindSeries = Color(hex: 0xA855F7)
    static let kindAnime = Color(hex: 0xF472B6)

    static let radiusSm: CGFloat = 9
    static let radius: CGFloat = 11
    static let radiusLg: CGFloat = 14

    /// The control tint (toggles, links, quiet accents). Never a status.
    static var indigo: Color { Color(hex: palette.i1) }
    /// 4K and grabbing, and nothing else.
    static var cyan: Color { grab }
    /// `--i1` / `--i2` aliases, so ports read like the CSS: the interface
    /// accent and its lighter (or, in Daylight, deeper) partner for links.
    static var i1: Color { indigo }
    static var i2: Color { Color(hex: palette.i2) }
    /// The primary action's fill. Text on it is `onPrimary`.
    static var fusion: LinearGradient { palette.primaryGradient }

    static var done: Color { Color(hex: palette.done) }
    static var grab: Color { Color(hex: palette.grab) }
    static var miss: Color { Color(hex: palette.miss) }
    static var unaired: Color { Color(hex: palette.unaired) }
    static var unmonitored: Color { Color(hex: palette.unmonitored) }
    static var onair: Color { Color(hex: palette.onair) }
    static var premiere: Color { Color(hex: palette.premiere) }
    static var stuck: Color { Color(hex: palette.stuck) }
    static var edition: Color { Color(hex: palette.edition) }
    static var anime: Color { Color(hex: palette.anime) }
    static var danger: Color { Color(hex: palette.danger) }
    static let plexGold = Color(hex: 0xE5A00D)

    /// The login screen's brand gradient (Login.module.css `.stage --grad`).
    static let loginGradient = LinearGradient(
        stops: [
            .init(color: Color(hex: 0x3B82F6), location: 0),
            .init(color: Color(hex: 0x8B5CF6), location: 0.38),
            .init(color: Color(hex: 0xD946EF), location: 0.66),
            .init(color: Color(hex: 0xF9A826), location: 1),
        ],
        startPoint: .leading, endPoint: .trailing)

    /// Library kind accents (`--kind-*`); animation rides the anime pink.
    static func kind(_ kind: LibraryKind) -> Color {
        switch kind {
        case .movie: return kindMovie
        case .series: return kindSeries
        case .anime, .animation: return kindAnime
        }
    }

    /// SegGroup active text.
    static var segActiveText: Color { txt }

    /// The redesign's 16pt side margin.
    static let pageGutter: CGFloat = 16
    static let bottomNavClearance: CGFloat = 76

    static func kind(_ bucket: KindBucket) -> Color {
        switch bucket {
        case .movie: return kindMovie
        case .series: return kindSeries
        case .anime: return kindAnime
        }
    }
}

// MARK: - Display type

extension Theme {
    /// Mona Sans Condensed (bundled, OFL): page and detail titles and the hero
    /// numbers only; every other string stays the system font. Scales with
    /// Dynamic Type relative to `style`.
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle, semibold: Bool = false) -> Font {
        Font(DisplayFace.font(size: size, weight: semibold ? 650 : 850, style: style) as CTFont)
    }

    /// Tight tracking for display sizes (-2% of the size).
    static func displayTracking(_ size: CGFloat) -> CGFloat { -size * 0.022 }
}

extension View {
    /// A page title in the display face: `Library`, `Activity`, `October`.
    func pageTitle(_ size: CGFloat = 56) -> some View {
        font(Theme.display(size)).tracking(Theme.displayTracking(size)).foregroundStyle(Theme.txt)
    }
}

extension RailState {
    /// Rail fill colour, from the web's RAIL_STATUS map.
    var color: Color {
        switch self {
        case .owned: return Theme.done
        case .partial, .wanted: return Theme.miss
        case .downloading: return Theme.grab
        case .upgrading: return Theme.edition
        case .upcoming: return Theme.unaired
        }
    }
}

extension CardStatus {
    /// `statusColor(CARD_STATUS_KEY[...])` (Library stats and the widget's Library view).
    var color: Color {
        switch self {
        case .downloading: return Theme.grab
        case .missing: return Theme.miss
        case .upcoming: return Theme.unaired
        case .complete: return Theme.done
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }
}

extension EditionStatus {
    /// Same status → colour mapping as the web's `status.ts`.
    var color: Color {
        switch self {
        case .downloaded: return Theme.done
        case .downloading, .available: return Theme.grab
        case .upgrading: return Theme.edition
        case .missing, .deadlink: return Theme.miss
        case .unaired, .upcoming: return Theme.unaired
        case .unmonitored, .other: return Theme.unmonitored
        case .onair: return Theme.onair
        case .premiere: return Theme.premiere
        case .stuck: return Theme.stuck
        }
    }
}

extension QualityTier {
    /// Tier chip colour: HD = edition purple, 4K = cyan.
    var color: Color { self == .hd ? Theme.edition : Theme.grab }
    /// The tier pill text on cards: `HD` / `4K`.
    var pill: String { self == .hd ? "HD" : "4K" }
}

/// A small edition chip, e.g. `UHD·4K` tinted by its status. Content, not glass.
struct EditionChip: View {
    let tier: QualityTier
    var status: EditionStatus? = nil
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let tint = status?.color ?? tier.color
        Text(tier.chipLabel)
            .font(.caption2.monospaced().weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(tint)
            .background(tint.opacity(0.14), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: Self.hairline(displayScale)))
            .accessibilityLabel("\(tier.chipLabel)\(status.map { ", \($0.label)" } ?? "")")
    }

    /// The 0.5pt border snapped to whole device pixels: 0.5pt is 1.5px at @3x,
    /// which leaves a half-covered, soft pixel row on every chip edge.
    static func hairline(_ scale: CGFloat) -> CGFloat {
        max(1, (0.5 * scale).rounded()) / max(scale, 1)
    }
}
