import SwiftUI
import FusionhaKit

/// One deck card (Final mock, web `SwipeCard` 0.4.217): the poster fills the
/// top; the title, "Requested by Priya + 2 · 3 d ago", the tier chip and the
/// source in words sit below it. Facts and the setup with Adjust live in
/// Details. While dragged, the APPROVE / DECLINE wash grows with distance
/// (Approve in the accent, as its button).
struct SwipeCardView: View {
    let request: MediaRequest
    let triage: RequestTriage?
    let dragX: CGFloat
    let warning: String?
    let approveBlocked: Bool

    private var title: String { request.title ?? "TMDB #\(request.tmdbId)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            art
            VStack(alignment: .leading, spacing: 0) {
                (Text(title).fontWeight(.heavy) + Text(verbatim: request.year.map { " (\($0))" } ?? "").fontWeight(.medium).foregroundColor(Theme.mut))
                    .font(.system(size: 19))
                    .foregroundStyle(Theme.txt)
                    .lineLimit(2)
                requestedBy
                    .padding(.top, 3).padding(.bottom, 10)
                HStack(spacing: 8) {
                    ForEach(request.tiers, id: \.self) { ActTierChip(tier: $0) }
                    Text(RequestLifecycle.sourceText(request.source)).lineLimit(1)
                }
                .font(.system(size: 13))
                .foregroundStyle(Theme.mut)
                if let held = request.held {
                    Label(held.label, systemImage: "hand.raised.fill")
                        .font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.miss)
                        .padding(.top, 8)
                }
                if let warning {
                    Text("\(warning) Swipe right again to approve anyway.")
                        .font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.txt)
                        .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                        .actWash(Theme.miss, radius: 10, base: Theme.card)
                        .padding(.top, 10)
                }
                RequestScopeLine(request: request, triage: triage, compact: true)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { washes }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.line))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    /// "Requested by **Priya** + 2 · 3 d ago".
    private var requestedBy: some View {
        let extra = max(0, (triage?.demand.count ?? 1) - 1)
        let age = TriageFacts.compactAge(request.requestedAt)
        return (Text("Requested by ") + Text(TriageFacts.firstName(TriageFacts.requesterName(request))).fontWeight(.semibold).foregroundColor(Theme.txt)
                + Text(extra > 0 ? " + \(extra)" : "") + Text(age.isEmpty ? "" : " · \(age) ago"))
            .font(.system(size: 14))
            .foregroundStyle(Theme.mut)
            .lineLimit(1)
    }

    /// The poster fills the top of the card (no text on the art).
    private var art: some View {
        PosterImage(url: TMDBImage.resized(request.poster, to: "w500"))
            .frame(height: 190)
            .frame(maxWidth: .infinity)
            .clipped()
            // The fill overflows its frame; clipped() hides it but not its
            // hit area, which reached over the header above the card.
            .allowsHitTesting(false)
            .background(Theme.panel2)
            .accessibilityHidden(true)
    }

    private var washes: some View {
        let approve = min(approveBlocked ? 0.3 : 1, max(0, dragX / 120))
        let decline = min(1, max(0, -dragX / 120))
        return ZStack {
            Theme.primary.opacity(0.35 * approve)
            Theme.danger.opacity(0.35 * decline)
            Text("APPROVE").font(.system(size: 30, weight: .heavy)).foregroundStyle(Theme.primary)
                .rotationEffect(.degrees(-12)).opacity(approve)
            Text("DECLINE").font(.system(size: 30, weight: .heavy)).foregroundStyle(Theme.danger)
                .rotationEffect(.degrees(12)).opacity(decline)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
