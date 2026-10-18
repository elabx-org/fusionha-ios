import SwiftUI
import FusionhaKit

/// One deck card (web `SwipeCard`): a blurred poster backdrop with the poster
/// and "Priya + 2", the title, tiers · kind · source, four facts, the usual
/// setup with Adjust and the scope line. While dragged, the APPROVE / DECLINE
/// wash grows with distance.
struct SwipeCardView: View {
    let request: MediaRequest
    let triage: RequestTriage?
    let dragX: CGFloat
    let warning: String?
    let approveBlocked: Bool
    let onAdjust: () -> Void

    private var title: String { request.title ?? "TMDB #\(request.tmdbId)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            art
            VStack(alignment: .leading, spacing: 10) {
                (Text(title).fontWeight(.bold) + Text(verbatim: request.year.map { " (\($0))" } ?? "").foregroundColor(Theme.mut))
                    .font(.system(size: 19))
                    .foregroundStyle(Theme.txt)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    ForEach(request.tiers, id: \.self) { ActTierChip(tier: $0) }
                    Text("· \(TriageFacts.kindText(request, isAnime: triage?.isAnime)) · \(RequestLifecycle.sourceText(request.source))")
                        .lineLimit(1)
                }
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.mut)
                if let held = request.held {
                    Label(held.label, systemImage: "hand.raised.fill")
                        .font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.miss)
                }
                if let warning {
                    Text("\(warning) Swipe right again to approve anyway.")
                        .font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.txt)
                        .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                        .actWash(Theme.miss, radius: 10, base: Theme.panel2)
                }
                facts
                ApproveSetupRow(triage: triage, own: false, compact: true, onAdjust: onAdjust)
                RequestScopeLine(request: request, triage: triage, compact: true)
            }
            .padding(14)
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { washes }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
    }

    private var art: some View {
        let extra = max(0, (triage?.demand.count ?? 1) - 1)
        return ZStack(alignment: .bottomLeading) {
            PosterImage(url: TMDBImage.resized(request.poster, to: "w342"))
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .blur(radius: 24)
                .opacity(0.55)
                .clipped()
                // The fill overflows its frame; clipped() hides it but not its
                // hit area, which reached over the lane tabs above the card.
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            HStack(alignment: .bottom, spacing: 12) {
                ActPoster(url: request.poster, title: title, size: .md)
                HStack(spacing: 6) {
                    RequestAvatar(name: TriageFacts.requesterName(request), size: 24, fontSize: 10.5)
                    (Text(TriageFacts.firstName(TriageFacts.requesterName(request))).fontWeight(.bold) + Text(extra > 0 ? " + \(extra)" : ""))
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.txt)
                }
                .padding(.leading, 3).padding(.trailing, 10).padding(.vertical, 3)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .padding(14)
        }
        .frame(height: 150)
        .background(Theme.panel2)
    }

    private var facts: some View {
        let size = TriageFacts.size(triage)
        let free = TriageFacts.freeAfter(triage)
        let four = TriageFacts.fourK(triage).tile
        let release = TriageFacts.release(triage)
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
            TriageTileView(label: "Size", value: Text(size.short), compact: true)
            TriageTileView(label: "Free after", value: Text(free.value), tone: free.tone, compact: true)
            TriageTileView(label: "4K release", value: Text(four.short), tone: four.tone, compact: true)
            TriageTileView(label: "Release", value: Text(release.short), tone: release.tone, compact: true)
        }
    }

    private var washes: some View {
        let approve = min(approveBlocked ? 0.3 : 1, max(0, dragX / 120))
        let decline = min(1, max(0, -dragX / 120))
        return ZStack {
            Theme.done.opacity(0.35 * approve)
            Theme.danger.opacity(0.35 * decline)
            Text("APPROVE").font(.system(size: 30, weight: .heavy)).foregroundStyle(Theme.done)
                .rotationEffect(.degrees(-12)).opacity(approve)
            Text("DECLINE").font(.system(size: 30, weight: .heavy)).foregroundStyle(Theme.danger)
                .rotationEffect(.degrees(12)).opacity(decline)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
