import SwiftUI
import FusionhaKit

/// The request thread's head on v2 (approved mock `rq-thread`): the clean
/// poster, the title large, "2026 · asked by eafx" with where it came from,
/// then the versions' media badges and the status pill. Joined viewers see
/// the joined pill in place of the source.
struct V2RequestThreadHeader: View {
    let request: MediaRequest
    let title: String
    let isOwner: Bool
    let joinedView: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ActPoster(url: request.poster, title: title, size: .md)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.txt)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) { askedLine; origin }
                    VStack(alignment: .leading, spacing: 4) { askedLine; origin }
                }
                HStack(spacing: 8) {
                    RequestTierBadges(request: request, showsResolution: true)
                    V2RequestStatusPill(status: request.status)
                }
                if !joinedView { RequestDemandLine(demand: request.demand) }
            }
            Spacer(minLength: 0)
        }
    }

    /// "2026 · asked by eafx".
    private var askedLine: some View {
        let who = (request.requester?.displayName).map { "asked by \($0)" }
        let parts = [request.year.map { String($0) }, who].compactMap { $0 }
        return Text(parts.joined(separator: " · "))
            .font(.system(size: 14))
            .foregroundStyle(Theme.mut)
            .lineLimit(1)
    }

    @ViewBuilder
    private var origin: some View {
        if joinedView {
            RequestJoinedPill(request: request)
        } else {
            RequestSourceBadge(source: request.source, mine: isOwner)
        }
    }
}
