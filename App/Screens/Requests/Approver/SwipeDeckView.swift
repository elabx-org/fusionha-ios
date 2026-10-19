import SwiftUI
import FusionhaKit

/// The phone inbox (web `SwipeDeck`): a stack of cards. Drag the top card
/// right to approve or left to decline; past the threshold it flies off and
/// the decision waits out the Undo. Approve waits for the card's triage; a
/// low-space card springs back with the warning and the second swipe confirms.
/// The viewer's own requests are left out of the deck (the list shows them),
/// except for an admin, who decides their own (fusionha 0.4.214).
struct SwipeDeckView: View {
    let inbox: InboxModel
    let viewerId: Int?
    let onDetails: (MediaRequest) -> Void
    let onSelectMode: () -> Void
    let onOpenThread: (MediaRequest) -> Void
    let onOpenBoard: () -> Void
    let onOpenHistory: (HistoryFilter) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drag: (id: Int, dx: CGFloat)?
    @State private var flying: (id: Int, right: Bool)?
    @State private var feedback = 0

    static let threshold: CGFloat = 110

    private var deck: [MediaRequest] {
        inbox.queue.filter { !inbox.isLocked($0, viewerId: viewerId) }
    }

    var body: some View {
        let deck = deck
        VStack(spacing: 14) {
            if let top = deck.first {
                HStack {
                    Text("Swipe right to approve · left to decline")
                    Spacer(minLength: 8)
                    Text(verbatim: "1 of \(deck.count)").monospacedDigit()
                }
                .font(.system(size: 13))
                .foregroundStyle(Theme.mut)
                // The top card over the edges of the ones beneath (Final mock):
                // the edges rise toward it as it is dragged away.
                card(top, position: 0, isTop: true)
                    .background(alignment: .bottom) {
                        DeckEdges(count: min(deck.count - 1, 2), lift: min(1, abs(offset(top.id)) / Self.threshold))
                    }
                    .id(top.id)
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .scale(scale: 0.94, anchor: .bottom).combined(with: .opacity),
                                                                     removal: .identity))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, deck.count > 2 ? 18 : deck.count > 1 ? 9 : 0)
                buttons(top)
            } else {
                InboxZeroView(ownOnly: !inbox.queue.isEmpty, onShowList: onSelectMode,
                              onOpenThread: onOpenThread, onOpenBoard: onOpenBoard, onOpenHistory: onOpenHistory)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: feedback)
    }

    private func card(_ request: MediaRequest, position: Int, isTop: Bool) -> some View {
        let t = inbox.triage[request.id]
        let dx: CGFloat = isTop ? offset(request.id) : 0
        let canApprove = TriageFacts.loaded(t) && !TriageFacts.setupMissing(t)
        return SwipeCardView(request: request, triage: t, dragX: isTop ? dx : 0,
                             warning: isTop && inbox.armedId == request.id ? TriageFacts.lowSpaceMessage(t) : nil,
                             approveBlocked: !canApprove)
            .scaleEffect(1 - CGFloat(position) * 0.04, anchor: .top)
            .offset(x: dx, y: CGFloat(position) * 12)
            .rotationEffect(.degrees(Double(dx) / 18))
            .allowsHitTesting(isTop)
            .accessibilityHidden(!isTop)
            .zIndex(Double(10 - position))
            .gesture(dragGesture(request, canApprove: canApprove))
            .onTapGesture { if isTop { onDetails(request) } }
            .accessibilityAction(named: "Approve") { fly(request, right: true, canApprove: canApprove) }
            .accessibilityAction(named: "Decline") { fly(request, right: false, canApprove: canApprove) }
    }

    private func offset(_ id: Int) -> CGFloat {
        if let flying, flying.id == id { return flying.right ? 700 : -700 }
        if let drag, drag.id == id { return drag.dx }
        return 0
    }

    /// Sideways only: a vertical drag on the card scrolls the page instead.
    private func dragGesture(_ request: MediaRequest, canApprove: Bool) -> HorizontalPanGesture {
        HorizontalPanGesture { dx in
            guard flying == nil else { return }
            let crossed = abs(drag?.dx ?? 0) > Self.threshold
            drag = (request.id, dx)
            if crossed != (abs(dx) > Self.threshold), dx < 0 || canApprove { feedback += 1 }
        } onEnded: { dx in
            if abs(dx) > Self.threshold {
                fly(request, right: dx > 0, canApprove: canApprove)
            } else {
                withAnimation(.spring(duration: 0.3)) { drag = nil }
            }
        }
    }

    /// Decline outlined in red, Details, Approve filled in the accent (Final mock).
    private func buttons(_ top: MediaRequest) -> some View {
        let t = inbox.triage[top.id]
        let canApprove = TriageFacts.loaded(t) && !TriageFacts.setupMissing(t)
        return HStack(spacing: 0) {
            Button { fly(top, right: false, canApprove: canApprove) } label: {
                Image(systemName: "xmark").font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.danger)
                    .frame(width: 62, height: 62)
                    .overlay(Circle().strokeBorder(Theme.danger, lineWidth: 2))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Decline")
            .frame(maxWidth: .infinity)
            Button("Details") { onDetails(top) }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.txt)
                .padding(.horizontal, 16).frame(height: 38)
                .glassEffect(.regular.interactive(), in: Capsule())
                .buttonStyle(.plain)
                .padding(.vertical, 3)
            Button { fly(top, right: true, canApprove: canApprove) } label: {
                Image(systemName: "checkmark").font(.system(size: 24, weight: .bold)).foregroundStyle(Theme.onAccent)
                    .frame(width: 62, height: 62)
                    .background(Theme.primary, in: Circle())
                    .opacity(canApprove ? 1 : 0.45)
            }
            .buttonStyle(.plain)
            .disabled(!canApprove)
            .accessibilityLabel(canApprove ? "Approve" : (TriageFacts.loaded(t) ? TriageFacts.setupMissingNote : "Checking space…"))
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    /// Decides the top card: approve needs triage; a low-space approve warns first.
    private func fly(_ request: MediaRequest, right: Bool, canApprove: Bool) {
        guard flying == nil else { return }
        if right {
            guard canApprove else {
                withAnimation(.spring(duration: 0.3)) { drag = nil }
                return
            }
            let t = inbox.triage[request.id]
            if TriageFacts.lowSpaceMessage(t) != nil && inbox.armedId != request.id {
                inbox.armedId = request.id
                feedback += 1
                withAnimation(.spring(duration: 0.3)) { drag = nil }
                return
            }
        }
        feedback += 1
        if reduceMotion {
            drag = nil
            decide(request, right: right)
            return
        }
        withAnimation(.easeIn(duration: 0.22)) { flying = (request.id, right) }
        Task {
            try? await Task.sleep(for: .milliseconds(230))
            decide(request, right: right)
            drag = nil
            flying = nil
        }
    }

    private func decide(_ request: MediaRequest, right: Bool) {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.3)) {
            if right {
                inbox.approve(request, viewerId: viewerId)
            } else {
                inbox.decline(request, viewerId: viewerId)
            }
        }
    }
}

/// The cards waiting under the top one, as two edges below it (Final mock):
/// the nearer edge narrower by 14 pt a side, the farther by 28; `lift` (0…1)
/// draws them up toward the top card while it is dragged away.
struct DeckEdges: View {
    let count: Int
    let lift: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(Array((0..<count).reversed()), id: \.self) { i in
                let depth = CGFloat(i + 1) * (1 - lift * 0.6)
                // panel2 alone sits too close to the page on dark palettes, so
                // each edge is lifted with a little of the text colour.
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.panel2)
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.txt.opacity(i == 0 ? 0.07 : 0.04)))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.line))
                    .padding(.horizontal, 14 * depth)
                    .offset(y: 9 * depth)
                    .opacity(i == 0 ? 1 : 0.7)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
