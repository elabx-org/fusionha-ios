import SwiftUI
import FusionhaKit

/// "Which version?" (web `VersionPicker`): one radio card per version the
/// reporter can see, tinted by its tier (HD purple, 4K cyan) when chosen.
struct IssueVersionPicker: View {
    let versions: [IssueVersionRef]
    let value: Int?
    let onChange: (Int) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(versions, id: \.id) { v in
                if let id = v.id, let tier = v.tier { card(id: id, tier: tier, edition: v.edition) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Which version?")
        .sensoryFeedback(.selection, trigger: value)
    }

    private func card(id: Int, tier: QualityTier, edition: String?) -> some View {
        let on = value == id
        let tint = tier.color
        return Button { onChange(id) } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle().strokeBorder(on ? tint : Theme.line, lineWidth: 1.5)
                    if on { Circle().fill(tint).padding(4) }
                }
                .frame(width: 16, height: 16)
                Text(IssueFormat.versionText(tier: tier, edition: edition))
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 48)
            .background(on ? tint.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(on ? tint.opacity(0.55) : Theme.line))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }
}
