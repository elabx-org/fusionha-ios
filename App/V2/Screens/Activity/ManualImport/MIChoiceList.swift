import SwiftUI
import FusionhaKit

/// A card's or a file's choices as radios (mock `choices`, shared with the
/// Queue's decision): Fusionha's pick is tagged on its option only where the
/// server gives one, every other option is an Override, and a chosen
/// override turns orange ("YOUR OVERRIDE"). A choice that costs you a copy
/// says so in red once chosen. Without a pick there are no tags: the chosen
/// option is in the accent.
struct MIChoiceList: View {
    struct Option: Identifiable {
        let choice: MIChoice
        let title: String
        let detail: String
        /// Deletes or replaces a copy you have.
        var loss = false
        var id: MIChoice { choice }
    }

    let options: [Option]
    let chosen: MIChoice?
    let pick: MIChoice?
    var dense = false
    let choose: (MIChoice) -> Void
    @Environment(\.pagePalette) private var page

    var body: some View {
        VStack(spacing: dense ? 6 : 7) {
            ForEach(options) { option($0) }
        }
        .sensoryFeedback(.selection, trigger: chosen)
    }

    private func option(_ o: Option) -> some View {
        let on = chosen == o.choice
        let override = pick != nil && o.choice != pick
        let tone: Color = on && o.loss ? Theme.danger : on && override ? Theme.stuck : Theme.primary
        return Button { choose(o.choice) } label: {
            HStack(alignment: .top, spacing: 11) {
                ZStack {
                    Circle().strokeBorder(Theme.txt.opacity(0.32), lineWidth: 2).opacity(on ? 0 : 1)
                    Circle().fill(tone).opacity(on ? 1 : 0)
                    Circle().fill(.white).frame(width: 8, height: 8).opacity(on ? 1 : 0)
                }
                .frame(width: 22, height: 22)
                .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    tag(o, on: on, override: override)
                    Text(o.title)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(page?.ink ?? Theme.txt)
                    Text(o.detail)
                        .font(.system(size: 12.5, weight: on && o.loss ? .semibold : .regular))
                        .foregroundStyle(on && o.loss ? Theme.danger : (page?.inkMuted ?? Theme.mut))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, dense ? 7 : 9)
            .background(tone.opacity(on ? 0.10 : 0), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(on ? tone : Theme.txt.opacity(0.12), lineWidth: on ? 2 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityValue(pick == o.choice ? "Fusionha’s pick" : override && on ? "Your override" : "")
    }

    @ViewBuilder private func tag(_ o: Option, on: Bool, override: Bool) -> some View {
        if pick != nil {
            let text = !override ? "FUSIONHA’S PICK" : on ? "YOUR OVERRIDE" : "OVERRIDE"
            let ink = override ? Theme.stuckText : Theme.primary
            Text(text)
                .font(.system(size: 10, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(ink)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(ink.opacity(0.16), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(.bottom, 3)
                .accessibilityHidden(true)
        }
    }
}
