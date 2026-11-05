import SwiftUI
import FusionhaKit

/// A held download in Needs you (plan S8, mock activity.js `vqRow`): poster,
/// title with the held ticket, what it is, then the problem in one line and
/// "Review". The mock's second line, Fusionha's pick ("Fusionha will …"),
/// waits on the server (API gap: no held pick or rationale per queue row), so
/// it is never guessed here and there is no "Do that". A tap opens the
/// decision panel; on the open Duo the open row carries the accent ring.
struct HeldRowSummary: View {
    let item: QueueItem
    /// Open on the right page (open Duo).
    var selected = false
    var checked: Bool?
    let review: () -> Void
    @Environment(\.pagePalette) private var page

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 11) {
                if let checked { V2SelectCheck(on: checked).padding(.top, 16) }
                PosterImage(url: TMDBImage.resized(item.posterUrl, to: "w185"), size: CGSize(width: 40, height: 60))
                    .frame(width: 40, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(item.title)
                            .font(.system(size: 15.5, weight: .bold))
                            .foregroundStyle(page?.ink ?? Theme.txt)
                            .lineLimit(1)
                        EditionBadge(tier: item.tier, state: .held, showsCount: false)
                        Spacer(minLength: 4)
                        if let time = V2QueueTime.clock(item.grabbedAt) {
                            Text(time).font(.caption.monospacedDigit()).foregroundStyle(page?.inkMuted ?? Theme.mut)
                        }
                    }
                    Text(HeldDecisionCopy.subtitle(item))
                        .font(.system(size: 12.5))
                        .foregroundStyle(page?.inkMuted ?? Theme.mut)
                        .lineLimit(1)
                }
            }
            problem.padding(.top, 8)
            if checked == nil {
                Button(action: review) {
                    Text("Review")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(page?.ink ?? Theme.txt)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .glassControl()
                .padding(.top, 10)
                .accessibilityHint("Shows what is wrong and every choice")
            }
        }
        .overlay {
            // The open row's ring, drawn just outside the row (selection is the accent).
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.primary, lineWidth: 2)
                .padding(-8)
                .opacity(selected ? 1 : 0)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    /// "! Under your 4K floor: scores +1,850" — the hold's words, orange
    /// mark, the lead in the ink and the rest muted.
    private var problem: some View {
        let reason = HeldDecisionCopy.problem(item)
        return HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(systemName: "exclamationmark")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.stuckText)
                .accessibilityHidden(true)
            (Text(reason.lead).fontWeight(.semibold).foregroundColor(page?.ink ?? Theme.txt)
             + Text(reason.detail.map { " \($0)" } ?? "").foregroundColor(page?.inkMuted ?? Theme.mut))
                .font(.system(size: 13))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
