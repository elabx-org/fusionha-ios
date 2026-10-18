import SwiftUI
import FusionhaKit

// MARK: Buttons (Button.module.css)

enum ActButtonKind { case primary, subtle, ghost, danger, warn, amber }

/// Capsules in the redesign: cream for the one primary action, glass for the
/// rest (danger and warn tint the text, never the glass), solid amber only for
/// the held-download call to action.
struct ActButtonStyle: ButtonStyle {
    var kind: ActButtonKind = .subtle
    var small = true
    /// 0…1: the capsule fills left to right (work with known progress).
    var fill: Double? = nil
    /// Overrides the text colour for a moment (a failed action's red).
    var tint: Color? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var height: CGFloat { small ? 32 : 36 }
    /// Glass reacts to touch itself (`.interactive()`); only solid capsules
    /// get the 0.97 press, so nothing presses twice.
    private var glass: Bool { [.subtle, .danger, .warn].contains(kind) }

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && !glass
        let label = configuration.label
            .font(.system(size: small ? 13 : 14, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, small ? 12 : 16)
            .frame(minHeight: height)
            .foregroundStyle(tint ?? foreground)
            .background(alignment: .leading) { fillBar }
        Group {
            switch kind {
            case .primary: label.background(Theme.fusion, in: Capsule())
            case .amber: label.background(Theme.miss, in: Capsule())
            case .ghost: label
            case .subtle, .danger, .warn: label.glassEffect(.regular.interactive(), in: Capsule())
            }
        }
        // fusionha 0.4.195: press = scale 0.97 + dim; dim only with Reduce Motion.
        .opacity(pressed ? 0.8 : 1)
        .scaleEffect(pressed && !reduceMotion ? 0.97 : 1)
        .animation(reduceMotion ? nil : .snappy(duration: 0.15), value: pressed)
        // A 44pt touch target around the drawn capsule, without moving the layout.
        .padding(.vertical, (44 - height) / 2)
        .contentShape(Rectangle())
        .padding(.vertical, -(44 - height) / 2)
    }

    @ViewBuilder
    private var fillBar: some View {
        if let fill {
            GeometryReader { geo in
                Rectangle().fill(foreground.opacity(0.18))
                    .frame(width: geo.size.width * min(max(fill, 0), 1))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: fill)
            }
            .clipShape(Capsule())
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary: return Theme.onPrimary
        case .subtle: return Theme.txt
        case .ghost: return Theme.mut
        case .danger: return Theme.danger
        case .warn: return Theme.miss
        case .amber: return Theme.bg
        }
    }
}

/// The row action button: a 32pt glass circle in a 44pt tap target.
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
            .foregroundStyle(tint == Theme.mut ? Theme.txt : tint)
            .frame(width: 32, height: 32)
            .glassEffect(.regular.interactive(), in: Circle())
            .frame(width: 40, height: 40)
            .padding(2)
            .contentShape(Rectangle())
            .padding(-2)
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

/// The queue `TierChip` as a lit edition chip: `HD·1080p` / `UHD·4K`, or the
/// version label when the version has a cut (`Extended · HD`, `VersionLabel`).
struct ActTierChip: View {
    let tier: QualityTier
    var big = false
    var edition: String? = nil
    var multipleEditions = false

    var body: some View {
        Text(VersionLabel.text(tier: tier, edition: edition, multipleEditions: multipleEditions)
             ?? (big ? tier.rawValue : tier.chipLabel))
            .font(.system(size: big ? 12 : 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(tier.color)
            .padding(.horizontal, big ? 7 : 5)
            .padding(.vertical, big ? 3 : 2)
            .background(EditionChipBackground(color: tier.color))
            .lineLimit(1)
            .fixedSize()
    }
}

/// `QualityChip`: a lit chip tinted by the quality's tier.
struct ActQualityChip: View {
    let quality: String

    var body: some View {
        let tint: Color = quality.contains("2160") ? Theme.grab : (quality.contains("1080") ? Theme.edition : Theme.mut)
        Text(ActFmt.quality(quality))
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(EditionChipBackground(color: tint))
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
            if let icon { Image(systemName: icon).font(.system(size: 11)) }
            Text(text)
        }
        .font(.system(size: 11, design: .monospaced))
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
                Image(systemName: meta.icon).font(.system(size: 11))
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
                if checked { Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(Theme.onPrimary) }
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
                (Text("\(count)").foregroundColor(Theme.i2).bold() + Text(" selected"))
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
