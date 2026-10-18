import SwiftUI
import FusionhaKit

/// The decision history (web `RequestStatusTimeline`): Requested → Approved /
/// Declined / Withdrawn → while tracked, each version's own row, and a hollow
/// "Available" stop until it's fulfilled.
struct RequestStatusTimeline: View {
    let request: MediaRequest

    var body: some View {
        let tracked = request.status == "approved" || request.status == "fulfilled"
        let fulfilled = request.status == "fulfilled"
        let lifecycle = request.lifecycle ?? []
        VStack(alignment: .leading, spacing: 14) {
            stop(.done(Theme.mut), title: Text("Requested"),
                 sub: [request.requester?.displayName, ActFmt.relative(request.requestedAt)].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
            if let by = request.approvedBy {
                let tiers = (request.tiers).map(\.chipLabel).joined(separator: " + ")
                stop(.done(Theme.i1),
                     title: Text(by.kind == "auto" ? RequestLifecycle.autoText(by) : "Approved by \(by.displayName ?? "an admin")"),
                     sub: [ActFmt.relative(request.decidedAt), tiers].filter { !$0.isEmpty }.joined(separator: " · "))
            }
            if let by = request.declinedBy {
                stop(.declined, title: Text("\(request.status == "deferred" ? "Not available yet" : "Declined") · \(by.displayName)"),
                     sub: request.decisionNote.map { "“\($0)”" })
            }
            if request.status == "withdrawn" {
                stop(.declined, title: Text("Withdrawn"), sub: nil)
            }
            if tracked {
                let lead = RequestLifecycle.lead(lifecycle)
                VStack(alignment: .leading, spacing: 8) {
                    stop(fulfilled ? .done(Theme.grab) : .current(Theme.grab),
                         title: Text(fulfilled ? "Available" : lead.map(leadTitle) ?? "In progress"),
                         sub: "Each version is tracked separately")
                    ForEach(Array(lifecycle.enumerated()), id: \.offset) { _, e in
                        HStack(spacing: 8) {
                            ActTierChip(tier: e.tier)
                            Text(RequestLifecycle.versionWord(e))
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(e.needsManualImport ? Theme.stuck : (e.step == .available ? Theme.done : Theme.txt))
                        }
                        .padding(.leading, 34)
                    }
                }
            }
            if tracked && !fulfilled {
                stop(.todo, title: Text("Available").foregroundColor(Theme.mut),
                     sub: "Plex will pick it up · you'll get a push if notifications are on")
            }
        }
    }

    private func leadTitle(_ lead: RequestLifecycleEntry) -> String {
        lead.step == .unreleased ? "Waiting" : RequestLifecycle.stopLabel(RequestLifecycle.stopIndex(lead.step), entry: lead, auto: false)
    }

    private enum Dot { case done(Color), current(Color), todo, declined }

    private func stop(_ dot: Dot, title: Text, sub: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            dotView(dot).frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                title.font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                if let sub, !sub.isEmpty {
                    Text(sub).font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func dotView(_ dot: Dot) -> some View {
        switch dot {
        case .done(let color):
            ZStack {
                Circle().fill(color)
                Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(Theme.bg)
            }
        case .current(let color):
            ZStack {
                Circle().strokeBorder(color, lineWidth: 2)
                Circle().fill(color).frame(width: 8, height: 8)
            }
        case .todo:
            Circle().strokeBorder(Theme.line, lineWidth: 1.5)
        case .declined:
            ZStack {
                Circle().fill(Theme.danger.opacity(0.18))
                Image(systemName: "xmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(Theme.danger)
            }
        }
    }
}

/// The conversation (web `ThreadTimeline`): messages as bubbles (the other
/// party's avatar on their side, a caption underneath), system events as
/// centred pills.
struct RequestConversation: View {
    let events: [RequestThreadEvent]
    let loaded: Bool
    let joinedView: Bool
    /// The request's projected source: names the list on a `created` line.
    var source: RequestSource? = nil

    var body: some View {
        if events.isEmpty {
            Text(loaded ? "No messages yet." : "Loading…")
                .font(.system(size: 13))
                .foregroundStyle(Theme.mut)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        } else {
            VStack(spacing: 10) {
                ForEach(events) { e in
                    if e.isMessage { bubble(e) } else { systemPill(e) }
                }
            }
        }
    }

    private func bubble(_ e: RequestThreadEvent) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if e.isMine { Spacer(minLength: 48) } else { avatar(e.actor) }
            VStack(alignment: e.isMine ? .trailing : .leading, spacing: 4) {
                Text(e.body ?? "")
                    .font(.system(size: 15))
                    .foregroundStyle(e.isMine ? Theme.onAccent : Theme.txt)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(e.isMine ? AnyShapeStyle(Theme.primary) : AnyShapeStyle(Theme.panel2),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .textSelection(.enabled)
                Text("\(RequestThreadFormat.messageMeta(e, joinedView: joinedView)) · \(ActFmt.relative(e.createdAt))")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.dim)
            }
            if !e.isMine { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func avatar(_ actor: RequestPerson?) -> some View {
        if let actor, actor.id != nil {
            Text(String(actor.displayName.prefix(1)).uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 26, height: 26)
                .background(Theme.i1, in: Circle())
                .accessibilityHidden(true)
        } else {
            Color.clear.frame(width: 26, height: 26)
        }
    }

    private func systemPill(_ e: RequestThreadEvent) -> some View {
        Text(RequestThreadFormat.systemLine(e, source: source))
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.mut)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Theme.panel2.opacity(0.7), in: Capsule())
            .frame(maxWidth: .infinity)
    }
}
