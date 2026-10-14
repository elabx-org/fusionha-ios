import SwiftUI
import UIKit
import FusionhaKit

// Small building blocks shared by the Detail*.swift files: tokens the theme
// lacks, section headers, the shelf-object card finish and the meta cell.
// Motion lives in DetailMotion, pills in DetailPills, buttons in
// DetailButtons, the toast in DetailToast and the wrapping row in DetailFlowRow.

enum DetailTokens {
    /// `--line2` (undefined in the web CSS; its intended value).
    static var line2: Color { Theme.txt.opacity(0.14) }
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

// MARK: - Section header

/// The redesign's section header (`.section-h`): sentence case, 20pt bold,
/// cream, with an optional quiet trailing note (counts, sizes).
struct DetailSection: View {
    let title: String
    var see: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(Theme.txt)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let see {
                Text(see)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.mut)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.top, 28)
        .padding(.bottom, 10)
    }
}

// MARK: - Shelf objects

extension View {
    /// A shelf object (`.obj`): version cards, edition cards, comparison
    /// panels. Solid content, never glass: a warm top-lit fill, a faint
    /// hairline and a soft falloff shadow.
    func detailCard(radius: CGFloat = 20, shadow: Bool = true) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background {
            shape
                .fill(LinearGradient(colors: [Theme.panel2, Theme.panel], startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(shadow ? 0.55 : 0), radius: shadow ? 14 : 0, y: shadow ? 10 : 0)
        }
        .overlay(shape.strokeBorder(Theme.txt.opacity(0.06), lineWidth: 0.5))
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
