import SwiftUI
import FusionhaKit

// The Request sheet's v2 pieces (look pass family 5, mock look-b.js
// `request`): sentence-case section labels, solid inset-grouped cards with
// hairlines on the system glass sheet, check circles (accent only when
// ticked) and each version as its monochrome media badge. v1 never draws
// these (`ProductLook.isV2`).

/// "Versions", "Note for the approver  optional".
struct RequestGroupLabel: View {
    let text: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.mut)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing).font(.system(size: 13)).foregroundStyle(Theme.dim)
            }
        }
        .padding(.horizontal, 4)
    }
}

/// One inset-grouped card: solid content on the glass sheet.
struct RequestGroupCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.txt.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// The hairline between a card's rows, inset past the check circle.
struct RequestRowDivider: View {
    var inset: CGFloat = 54

    var body: some View {
        Divider().padding(.leading, inset)
    }
}

/// A round check: the accent fill and a tick when on, a quiet ring when off.
struct RequestCheckCircle: View {
    let checked: Bool
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            if checked {
                Circle().fill(Theme.primary)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
            } else {
                Circle().strokeBorder(Theme.txt.opacity(0.35), lineWidth: 1.5)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A version to request: check, its media badge (outline: you don't have
/// it), the quality, then what ticking it does.
struct RequestVersionRow: View {
    let tier: QualityTier
    let selected: Bool
    let act: RequestOffer.Act?
    let asked: Int
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                RequestCheckCircle(checked: selected)
                EditionBadge(tier: tier, state: .missing, showsCount: false)
                Text(tier.rawValue)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.txt)
                Spacer(minLength: 0)
                if let act { RequestTierTag(act: act, asked: asked) }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
