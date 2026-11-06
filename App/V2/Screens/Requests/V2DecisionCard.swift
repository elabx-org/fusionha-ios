import SwiftUI
import FusionhaKit

/// What the decision card's buttons and menu do (the Inbox wires them to
/// `InboxModel`, so every choice keeps the 5 s Undo).
struct V2DecisionActions {
    let approve: () -> Void
    /// Not yet: reject with defer ("Not available yet"), no reason sheet.
    let notYet: () -> Void
    /// Decline: asks for a reason first.
    let decline: () -> Void
    let adjust: () -> Void
    let message: () -> Void
    let openTitle: () -> Void
}

/// v2's decision card (mock requests.js `dcard` / `decisionPane`): the
/// problem is "approve or not". A frosted header card (poster, title,
/// status, who asked and from where), the six triage facts, the plan
/// sentence saying what Approve does, then Decline · Not yet · Approve.
/// Content sits on W1 cards over the page ground; only the buttons are glass.
struct V2DecisionCard: View {
    let request: MediaRequest
    let triage: RequestTriage?
    let own: Bool
    let armed: Bool
    /// The wide pane: the overrides are spelled out and Approve names its versions.
    var wide = false
    let actions: V2DecisionActions

    private var title: String { request.title ?? "TMDB #\(request.tmdbId)" }
    private var requester: String { TriageFacts.requesterName(request) }

    var body: some View {
        let plan = DecisionPlan.sentence(title: title, tiers: request.tiers, triage: triage,
                                         requester: requester, own: own)
        VStack(alignment: .leading, spacing: 12) {
            V2DecisionHeader(request: request, triage: triage, own: own, actions: actions)
                .v2CardStyle()
            if let held = request.held { RequestHeldNote(held: held) }
            VStack(alignment: .leading, spacing: 14) {
                DecisionTiles(request: request, triage: triage)
                DecisionPlanLine(sentence: plan, showsOverrides: wide, canAdjust: !own && triage != nil,
                                 onAdjust: actions.adjust)
                RequestScopeLine(request: request, triage: triage)
            }
            .v2CardStyle()
            warning
            DecisionActionBar(approveLabel: approveLabel, approveDisabled: plan.blocked,
                              decideDisabled: own,
                              onDecline: actions.decline, onNotYet: actions.notYet, onApprove: actions.approve)
        }
    }

    private var approveLabel: String {
        if armed && TriageFacts.lowSpaceMessage(triage) != nil { return "Approve anyway" }
        if !TriageFacts.loaded(triage) { return "Checking space…" }
        if let scope = RequestScope.head(request, fromEpisode: false) { return "Approve \(scope)" }
        guard wide else { return "Approve" }
        return "Approve in " + request.tiers.map(\.rawValue).joined(separator: " + ")
    }

    @ViewBuilder
    private var warning: some View {
        if armed, let lowSpace = TriageFacts.lowSpaceMessage(triage) {
            Text("\(lowSpace) Approve again to go ahead anyway.")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.txt)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .actWash(Theme.stuck, radius: 14, base: Theme.panel2)
        }
    }
}

/// The card's head: poster (clean, no text on it), title and year, kind ·
/// runtime, the status pill, who asked and from where, their note, and the
/// More menu (open the title, message, approve with changes, decline with a note).
private struct V2DecisionHeader: View {
    let request: MediaRequest
    let triage: RequestTriage?
    let own: Bool
    let actions: V2DecisionActions

    private var title: String { request.title ?? "TMDB #\(request.tmdbId)" }

    var body: some View {
        let name = TriageFacts.requesterName(request)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                PosterImage(url: TMDBImage.resized(request.poster, to: "w185"))
                    .frame(width: 64, height: 96)
                    .shelfPoster(radius: 10)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    (Text(title).fontWeight(.bold) + Text(verbatim: request.year.map { " (\($0))" } ?? "").foregroundColor(Theme.mut))
                        .font(.title3)
                        .foregroundStyle(Theme.txt)
                        .lineLimit(3)
                    Text(metaLine).font(.footnote).foregroundStyle(Theme.mut).lineLimit(2)
                    RequestStatusPill(status: request.status, age: TriageFacts.compactAge(request.requestedAt))
                }
                Spacer(minLength: 0)
                menu(name)
            }
            HStack(spacing: 8) {
                RequestAvatar(name: name, size: 26, fontSize: 11.5)
                (Text(TriageFacts.firstName(name)).fontWeight(.semibold).foregroundColor(Theme.txt)
                    + Text(own ? " (you)" : "") + Text(" · \(RequestLifecycle.sourceText(request.source))"))
                    .font(.footnote).foregroundStyle(Theme.mut).lineLimit(1)
                Spacer(minLength: 0)
                if let badge = TriageFacts.trackBadge(triage, role: request.requester?.role) {
                    Text(badge.label)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(badge.trusted ? Theme.txt : Theme.mut)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Theme.mut.opacity(0.14), in: Capsule())
                }
            }
            if let note = request.note, !note.isEmpty {
                Text("“\(note)”").font(.subheadline.italic()).foregroundStyle(Theme.txt)
            }
        }
    }

    private var metaLine: String {
        var parts = [TriageFacts.kindText(request, isAnime: triage?.isAnime)]
        if let minutes = triage?.runtimeMinutes, minutes > 0 {
            parts.append(minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m")
        }
        return parts.joined(separator: " · ")
    }

    private func menu(_ name: String) -> some View {
        Menu {
            Button(action: actions.openTitle) { Label("Open title", systemImage: "arrow.up.right.square") }
            Button(action: actions.message) {
                Label("Message \(TriageFacts.firstName(name))", systemImage: "bubble.left.and.bubble.right")
            }
            Divider()
            Button(action: actions.adjust) { Label("Approve with changes…", systemImage: "checkmark") }.disabled(own)
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.mut)
                .frame(width: 36, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More actions")
    }
}
