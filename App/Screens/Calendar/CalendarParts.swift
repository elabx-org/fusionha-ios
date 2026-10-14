import SwiftUI
import FusionhaKit

// Small pieces shared by the Calendar views and the Account / sign-in screens:
// the colour mappings and the web's `sm` buttons. The edition rail, glyphs,
// empty state, toast and motion live in their own files beside this one.

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
    /// Release types are not statuses, so they stay in the house-light family
    /// (brass, pale brass, ink-2): cyan and violet mean 4K / grabbing and HD.
    var color: Color {
        switch self {
        case .theatrical: return Theme.indigo
        case .digital: return Theme.i2
        case .physical: return Theme.mut
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
    /// The 3pt kind tick (month pills): the only place kind accents appear
    /// (DIRECTION.md): anime pink, movie sky, series purple.
    var accent: Color {
        if isAnime { return Theme.kindAnime }
        if isMovie { return Theme.kindMovie }
        return Theme.kindSeries
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
