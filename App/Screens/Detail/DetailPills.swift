import SwiftUI
import FusionhaKit

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
                Image(systemName: "clock").font(.system(size: 11, weight: .semibold)).detailPulse(low: 0.4, high: 1, period: 2)
                Text("Upcoming")
            case .upgrading:
                Image(systemName: "arrow.up").font(.system(size: 11, weight: .bold))
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

/// The owned-quality chip (`DetailQualityChip`): mono 10/700, a lit chip in the tier colour.
struct DetailQualityChip: View {
    let quality: String?
    let tier: QualityTier

    var body: some View {
        let color = DetailTokens.tier(tier)
        Text(DetailText.quality(quality))
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(EditionChipBackground(color: color))
    }
}

/// A version tag (`Black & White`) next to a tier label.
struct DetailVersionTag: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Theme.mut)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Theme.txt.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
    }
}
