import SwiftUI
import FusionhaKit

/// One Inbox thread on v2 (approved mock `rq-notify`): poster, title, a
/// small state mark and "Imported · available in HD" (the request's step
/// or the issue's problem and state), who is on it or the newest message,
/// and the date with an unread dot on the right. Rows sit in one grouped
/// card (`RequestsGroup`); the status colour lives in the mark, not a wash.
struct V2ThreadRow: View {
    let item: ThreadItem

    var body: some View {
        let title = ThreadMeta.title(item)
        let issue = item.type == "issue" ? item.issue : nil
        HStack(spacing: 12) {
            ActPoster(url: item.poster ?? issue?.poster ?? item.request?.poster, title: title, size: .sm)
                .frame(width: 36, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                HStack(spacing: 6) {
                    Image(systemName: mark.symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(mark.tint)
                        .accessibilityHidden(true)
                    RequestTierBadges(tiers: ThreadMeta.tiers(item), states: states)
                    Text(stepLine).lineLimit(1)
                }
                .font(.system(size: 14))
                .foregroundStyle(Theme.mut)
                if let sub = subLine {
                    Text(sub).font(.system(size: 13)).foregroundStyle(Theme.dim).lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 6) {
                Text(ActFmt.relative(item.lastEventAt)).font(.system(size: 13).monospacedDigit()).foregroundStyle(Theme.dim)
                if ThreadMeta.hasUnread(item) {
                    Circle().fill(Theme.primary).frame(width: 8, height: 8).accessibilityLabel("Unread")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 70)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// "Request · Approved" or "Won't play · Checking".
    private var stepLine: String {
        [ThreadMeta.lineLabel(item), ThreadMeta.stateLabel(item)].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// The newest message, else who is on the thread (and who it waits on).
    private var subLine: String? {
        if let message = item.lastMessage { return message.line }
        let people = ThreadMeta.people(item)
        guard let first = people.first else { return nil }
        let who = first.name + (people.count > 1 ? " +\(people.count - 1)" : "")
        return ThreadMeta.waitingOn(item).map { "\(who) · waiting on \($0)" } ?? who
    }

    private var states: [QualityTier: EditionBadgeState] {
        if let r = item.request { return RequestBadgeStates.states(r) }
        var out: [QualityTier: EditionBadgeState] = [:]
        for tier in ThreadMeta.tiers(item) { out[tier] = .onDisk }
        return out
    }

    /// One quiet mark: done in the label colour, active in the accent,
    /// waiting on a person in orange only when it waits on the viewer's side.
    private var mark: (symbol: String, tint: Color) {
        if item.type == "issue" {
            switch item.issue?.state {
            case "RESOLVED": return ("checkmark.circle", Theme.txt)
            case "CHECKING", "FIXING": return ("clock", Theme.accentText)
            case "NEEDS_ADMIN": return ("exclamationmark.circle", Theme.stuck)
            default: return ("flag", Theme.mut)
            }
        }
        switch item.request?.status {
        case "fulfilled", "available": return ("checkmark.circle", Theme.txt)
        case "approved": return ("clock", Theme.accentText)
        case "pending", "waiting": return ("exclamationmark.circle", Theme.stuck)
        case "rejected", "declined": return ("xmark.circle", Theme.danger)
        default: return ("circle", Theme.mut)
        }
    }
}
