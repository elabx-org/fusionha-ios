import SwiftUI
import FusionhaKit

/// Wide Home: the focused Coming up title beside the carousel (Home mock,
/// open): when, the title, what is coming, its HD/4K tickets, then Open
/// (the primary action, in the accent) and Calendar. Follows the swipe.
struct V2ComingUpDetail: View {
    let card: V2ComingUpCard
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page
    @Environment(\.motionEnabled) private var motion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(card.when.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(page?.inkMuted ?? Theme.mut)
            Text(card.item.title)
                .font(.system(size: 34, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(page?.ink ?? Theme.txt)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
            Text(card.what)
                .font(.system(size: 17))
                .foregroundStyle(page?.inkMuted ?? Theme.mut)
                .lineLimit(1)
            V2ItemTickets(item: card.item)
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    Button("Open") { model.open(card.item.id) }
                        .buttonStyle(.glassProminent)
                        .tint(Theme.indigo)
                    Button("Calendar") { model.tab = .calendar }
                        .buttonStyle(.glass)
                }
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: 380, alignment: .leading)
        .id(card.id)
        .transition(.opacity)
        .animation(motion ? .easeOut(duration: 0.2) : nil, value: card.id)
    }
}
