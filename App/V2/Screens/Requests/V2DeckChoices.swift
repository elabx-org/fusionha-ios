import SwiftUI
import FusionhaKit

/// Under v2's deck card (mock requests.js `inboxPhone`): the plan sentence
/// on a W1 card, then Decline · Not yet · Approve. Not yet and Approve fly
/// the card as the swipes do; Decline opens the reason sheet.
struct V2DeckChoices: View {
    let request: MediaRequest
    let triage: RequestTriage?
    let armed: Bool
    let onDecline: () -> Void
    let onNotYet: () -> Void
    let onApprove: () -> Void

    var body: some View {
        let title = request.title ?? "TMDB #\(request.tmdbId)"
        let plan = DecisionPlan.sentence(title: title, tiers: request.tiers, triage: triage,
                                         requester: TriageFacts.requesterName(request), own: false)
        VStack(spacing: 12) {
            DecisionPlanLine(sentence: plan, showsOverrides: false, canAdjust: false, onAdjust: {})
                .v2CardStyle(padding: 14, radius: 18)
            DecisionActionBar(approveLabel: label, approveDisabled: plan.blocked,
                              onDecline: onDecline, onNotYet: onNotYet, onApprove: onApprove)
        }
    }

    private var label: String {
        if armed && TriageFacts.lowSpaceMessage(triage) != nil { return "Approve anyway" }
        return TriageFacts.loaded(triage) ? "Approve" : "Checking…"
    }
}
