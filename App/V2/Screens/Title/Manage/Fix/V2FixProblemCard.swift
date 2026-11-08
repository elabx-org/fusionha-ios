import SwiftUI
import FusionhaKit

/// Fix mode's problem card (mock frame 1): the held media badge, what is
/// wrong in plain words and the recommended fix, one block per kind of
/// problem. Solid content with an orange hairline; orange is the only hue.
struct V2FixProblemCard: View {
    let tier: QualityTier?
    let groups: [ManageFixGroup]
    /// The one problem file's episode title, for "MediaInfo couldn't open Amari".
    let name: String?
    @Environment(\.pagePalette) private var page

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let tier {
                EditionBadge(tier: tier, state: .held, showsCount: false)
                    .padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(groups) { block($0) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            ZStack {
                ModuleSurface(radius: 22)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Theme.stuck.opacity(0.4), lineWidth: 1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func block(_ group: ManageFixGroup) -> some View {
        let fix = group.bestFix
        return VStack(alignment: .leading, spacing: 4) {
            Text(group.headline)
                .font(.system(size: 15.5, weight: .bold))
                .foregroundStyle(ink)
            Text(group.explanation(name: group.items.count == 1 ? name : nil))
                .font(.system(size: 13.5))
                .foregroundStyle(muted)
                .fixedSize(horizontal: false, vertical: true)
            (Text("Best fix: ") + Text(fix.fix).bold() + Text(". " + fix.why))
                .font(.system(size: 13.5))
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
