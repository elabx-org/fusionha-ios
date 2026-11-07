import SwiftUI
import FusionhaKit

/// The focused title under the open Duo's carousel: WHEN, the title, the
/// network mark with what is coming, and the HD/4K tickets. Posters centres
/// it; Backdrops sets it flush with the card's left edge with Open (the
/// primary action, in the accent) on the right. Follows the swipe.
struct V2ComingUpWideInfo: View {
    let card: V2ComingUpCard
    let style: V2ComingUpWideStyle
    /// The centre card's width (Backdrops lines up with it).
    let width: CGFloat
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page
    @Environment(\.motionEnabled) private var motion

    var body: some View {
        Group {
            switch style {
            case .posters:
                text(.center).frame(maxWidth: .infinity)
            case .backdrops:
                HStack(alignment: .bottom, spacing: 16) {
                    text(.leading)
                    Spacer(minLength: 0)
                    Button("Open") { model.open(card.item.id) }
                        .buttonStyle(.glassProminent)
                        .tint(Theme.indigo)
                }
                .frame(width: width)
                .frame(maxWidth: .infinity)
            }
        }
        .id(card.id)
        .transition(.opacity)
        .animation(motion ? .easeOut(duration: 0.2) : nil, value: card.id)
    }

    private func text(_ alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(card.when.uppercased())
                .font(.system(size: 11.5, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(page?.inkMuted ?? Theme.mut)
            Text(card.item.title)
                .font(.system(size: style == .posters ? 22 : 24, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(page?.ink ?? Theme.txt)
                .minimumScaleFactor(0.8)
            HStack(spacing: 10) {
                V2ItemMarkLine(item: card.item, spacing: 7) {
                    Text(card.what)
                        .font(.system(size: 14))
                        .foregroundStyle(page?.inkMuted ?? Theme.mut)
                }
                V2ItemTickets(item: card.item)
            }
            .padding(.top, 3)
        }
        .lineLimit(1)
        .multilineTextAlignment(alignment == .center ? .center : .leading)
        .accessibilityElement(children: .combine)
    }
}
