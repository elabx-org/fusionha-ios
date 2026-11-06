import SwiftUI

/// A Home section's heading (Home mock `.kh`/`.rh`): the name at 21pt bold
/// and, at the trailing end, the way in ("See all 12", "2,636 ›").
struct V2HomeSectionHead: View {
    let title: String
    var action: String?
    var chevron = false
    var accessibilityAction: String?
    var tap: () -> Void = {}
    @Environment(\.pagePalette) private var page

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.system(size: 21, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(page?.ink ?? Theme.txt)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let action {
                Button(action: tap) {
                    HStack(spacing: 4) {
                        Text(action).monospacedDigit()
                        if chevron { Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)) }
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityAction ?? action)
            }
        }
    }
}
