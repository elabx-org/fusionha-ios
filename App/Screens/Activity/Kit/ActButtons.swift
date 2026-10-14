import SwiftUI
import FusionhaKit

// MARK: Buttons (Button.module.css)

enum ActButtonKind { case primary, subtle, ghost, danger, warn, amber }

struct ActButtonStyle: ButtonStyle {
    var kind: ActButtonKind = .subtle
    var small = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: small ? 12 : 13, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, small ? 11 : 14)
            .frame(minHeight: small ? 30 : 36)
            .foregroundStyle(foreground)
            .background { background }
            .overlay {
                if let border {
                    RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(border)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }

    private var foreground: Color {
        switch kind {
        case .primary: return Theme.bg
        case .subtle: return Theme.txt
        case .ghost: return Theme.mut
        case .danger: return Theme.danger
        case .warn: return Theme.miss
        case .amber: return Color(hex: 0x1A1206)
        }
    }

    private var border: Color? {
        switch kind {
        case .danger: return Theme.danger.opacity(0.4)
        case .warn: return Theme.miss.opacity(0.45)
        case .subtle: return Theme.line
        default: return nil
        }
    }

    @ViewBuilder
    private var background: some View {
        switch kind {
        case .primary: RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.fusion)
        case .subtle: RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.panel)
        case .amber: RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.miss)
        default: Color.clear
        }
    }
}

/// The 26pt `.iact` / `.ib` row action button (40pt tap target).
struct ActIconButton: View {
    let systemImage: String
    let label: String
    var tint: Color = Theme.mut
    var busy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if busy {
                    ProgressView().controlSize(.mini).tint(tint)
                } else {
                    Image(systemName: systemImage).font(.system(size: 13, weight: .semibold))
                }
            }
            .foregroundStyle(tint)
            .frame(width: 26, height: 26)
            .background(tint == Theme.mut ? Color.clear : tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .accessibilityLabel(label)
    }
}

/// The `⋯` ActionMenu trigger (native Menu, CLAUDE.md: native controls).
struct ActMoreMenu<Content: View>: View {
    var label = "More actions"
    @ViewBuilder var content: Content

    var body: some View {
        Menu {
            content
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.dim)
                .frame(width: 26, height: 26)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: Chips

/// The queue `TierChip`: mono 9/700, `HD·1080p` / `UHD·4K`.
struct ActTierChip: View {
    let tier: QualityTier
    var big = false

    var body: some View {
        Text(big ? tier.rawValue : tier.chipLabel)
            .font(.system(size: big ? 10 : 9, weight: .bold, design: .monospaced))
            .foregroundStyle(tier.color)
            .padding(.horizontal, big ? 7 : 5)
            .padding(.vertical, 1)
            .background(tier.color.opacity(big ? 0.12 : 0.06), in: RoundedRectangle(cornerRadius: big ? 6 : 4))
            .overlay(RoundedRectangle(cornerRadius: big ? 6 : 4).strokeBorder(tier.color.opacity(0.4)))
            .lineLimit(1)
            .fixedSize()
    }
}

/// `QualityChip`: mono 10/700, tinted by the quality's tier.
struct ActQualityChip: View {
    let quality: String

    var body: some View {
        let tint: Color = quality.contains("2160") ? Theme.grab : (quality.contains("1080") ? Theme.edition : Theme.mut)
        Text(ActFmt.quality(quality))
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(tint.opacity(0.3)))
            .lineLimit(1)
            .fixedSize()
    }
}

/// A small mono meta chip (panel2, r6).
struct ActMonoChip: View {
    let text: String
    var color: Color = Theme.mut
    var border: Color = Theme.line
    var icon: String?

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 9)) }
            Text(text)
        }
        .font(.system(size: 10.5, design: .monospaced))
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 1)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(border))
        .lineLimit(1)
        .fixedSize()
    }
}

/// `ProvenanceChip` (grab_trigger).
struct ActProvenance: View {
    let trigger: String

    var body: some View {
        if let meta = Self.meta(trigger) {
            HStack(spacing: 4) {
                Image(systemName: meta.icon).font(.system(size: 10))
                Text(meta.label)
            }
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(meta.color)
            .padding(.leading, 6)
            .padding(.trailing, 8)
            .padding(.vertical, 4)
            .background(meta.color.opacity(0.1), in: Capsule())
            .overlay(Capsule().strokeBorder(meta.color.opacity(0.25)))
            .lineLimit(1)
            .fixedSize()
        }
    }

    static func meta(_ trigger: String) -> (label: String, icon: String, color: Color)? {
        switch trigger.lowercased() {
        case "rss": return ("RSS", "dot.radiowaves.up.forward", Theme.dim)
        case "search": return ("Search", "magnifyingglass", Theme.dim)
        case "upgrade": return ("Upgrade", "arrow.up", Theme.dim)
        case "interactive": return ("Interactive", "person", Theme.indigo)
        case "forced": return ("Forced", "bolt", Theme.indigo)
        case "regrab": return ("Re-grabbed", "arrow.clockwise", Theme.indigo)
        case "requested", "request": return ("Requested", "tray.and.arrow.down", Theme.edition)
        default: return nil
        }
    }
}

// MARK: Select checkbox + bulk bar

struct ActCheckbox: View {
    let checked: Bool
    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(checked ? AnyShapeStyle(Theme.fusion) : AnyShapeStyle(Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(checked ? Color.clear : Theme.mut, lineWidth: 1.5))
            .overlay {
                if checked { Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(Theme.onPrimary) }
            }
            .frame(width: 18, height: 18)
            .accessibilityLabel(checked ? "Selected" : "Not selected")
    }
}

extension View {
    /// The selected-row treatment: indigo border + 6% indigo fill.
    func actSelected(_ on: Bool, radius: CGFloat = 14) -> some View {
        overlay {
            if on {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.indigo.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.indigo.opacity(0.45)))
                    .allowsHitTesting(false)
            }
        }
    }
}

/// The sticky glass bulk-action bar (`.bulkbar`).
struct ActBulkBar<Actions: View>: View {
    let count: Int
    var hint: String?
    let onSelectAll: () -> Void
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                (Text("\(count)").foregroundColor(Theme.cyan).bold() + Text(" selected"))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.mut)
                Button("Select all", action: onSelectAll)
                    .buttonStyle(ActButtonStyle(kind: .ghost))
                Spacer(minLength: 0)
            }
            ActFlow(spacing: 8, lineSpacing: 8) { actions }
            if let hint {
                Text(hint).font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 11)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.indigo.opacity(0.4)))
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }
}
