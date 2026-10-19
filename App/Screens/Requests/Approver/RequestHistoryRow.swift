import SwiftUI
import FusionhaKit

/// One decided request (web `HistoryRow` / `RecentlyDecided`): poster, title,
/// tiers, "Requested by · approved by · when", the status pill and the time
/// to available. `compact` is the inbox-zero list's shorter row.
struct RequestHistoryRow: View {
    let request: MediaRequest
    var compact = false

    var body: some View {
        let title = request.title ?? "TMDB #\(request.tmdbId)"
        let pill = RequestBoard.historyPill(request)
        HStack(alignment: .top, spacing: 10) {
            ActPoster(url: request.poster, title: title, size: .sm)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    (Text(title).fontWeight(.semibold) + Text(verbatim: request.year.map { " (\($0))" } ?? "").foregroundColor(Theme.mut))
                        .font(.system(size: 14)).foregroundStyle(Theme.txt).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(pill.label)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(pill.tone.color)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(pill.tone.color.opacity(0.15), in: Capsule())
                        .fixedSize()
                }
                HStack(spacing: 5) {
                    ForEach(request.tiers, id: \.self) { ActTierChip(tier: $0) }
                    if !compact && request.availableAt != nil {
                        Label(RequestBoard.timeToAvailable(request), systemImage: "timer")
                            .font(.system(size: 11.5).monospacedDigit()).foregroundStyle(Theme.mut)
                            .accessibilityLabel("Time to available \(RequestBoard.timeToAvailable(request))")
                    }
                }
                Text(metaLine).font(.system(size: 12)).foregroundStyle(Theme.mut).lineLimit(2)
            }
            Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 13)).foregroundStyle(Theme.dim)
                .padding(.top, 2)
                .accessibilityHidden(true)
        }
        .padding(10)
        .actWash(RequestLifecycle.wash(status: request.status, lifecycle: request.lifecycle ?? []).color, radius: 14, base: Theme.card)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the conversation")
    }

    /// "Requested by Sam · approved by Ana · 2 days ago", a dot only between parts that show.
    private var metaLine: String {
        var parts: [String] = []
        if let who = request.requester?.displayName { parts.append("\(compact ? "Asked" : "Requested") by \(who)") }
        if let by = request.approvedBy {
            parts.append(by.kind == "auto" ? RequestLifecycle.autoText(by) : "approved by \(by.displayName ?? "an admin")")
        } else if let by = request.declinedBy {
            parts.append("declined by \(by.displayName)")
        }
        let when = ActFmt.relative(compact ? (request.decidedAt ?? request.availableAt ?? request.requestedAt) : request.requestedAt)
        if !when.isEmpty { parts.append(when) }
        return parts.joined(separator: " · ")
    }
}
