import SwiftUI

/// One v2 Account row (mock requests.js `acctGroups`): the hued icon tile,
/// the title with an optional second line, a trailing value or count pill,
/// and a chevron or ↗ for rows that leave the sheet.
struct V2AccountRow: View {
    enum Accessory { case none, chevron, external }

    let icon: String
    let tint: Color
    let title: String
    var subtitle: String?
    var value: String?
    /// An orange count (needs review): only for what needs the owner.
    var attention: Int = 0
    var accessory: Accessory = .chevron

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.isMono ? Theme.bg : Theme.onTint(tint))
                .frame(width: 28, height: 28)
                .background(Theme.isMono ? Theme.mut : tint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(Theme.txt)
                if let subtitle {
                    Text(subtitle).font(.footnote).foregroundStyle(Theme.mut).lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            if attention > 0 {
                Text("\(attention)")
                    .font(.footnote.weight(.bold)).monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).frame(minWidth: 22, minHeight: 22)
                    .background(Theme.stuck, in: Capsule())
                    .accessibilityLabel("\(attention) need review")
            } else if let value {
                Text(value).foregroundStyle(Theme.mut).monospacedDigit()
            }
            switch accessory {
            case .chevron:
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.dim)
            case .external:
                Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.dim)
            case .none:
                EmptyView()
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
