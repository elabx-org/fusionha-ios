import SwiftUI
import FusionhaKit

/// The phone inbox (web `SwipeDeck`): a stack of cards. Drag the top card
/// right to approve or left to decline; past the threshold it flies off and
/// the decision waits out the Undo. Approve waits for the card's triage; a
/// low-space card springs back with the warning and the second swipe confirms.
/// The viewer's own requests are left out of the deck (the list shows them).
struct SwipeDeckView: View {
    let inbox: InboxModel
    let viewerId: Int?
    let onDetails: (MediaRequest) -> Void
    let onAdjust: (MediaRequest) -> Void
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
        inbox.queue.filter { !inbox.isOwn($0, viewerId: viewerId) }
    }

    var body: some View {
        let deck = deck
        VStack(spacing: 14) {
            header(deck)
            if let top = deck.first {
                ZStack {
                    ForEach(Array(Array(deck.prefix(3).enumerated()).reversed()), id: \.element.id) { position, request in
                        card(request, position: position, isTop: request.id == top.id)
                    }
                }
                .frame(maxWidth: .infinity)
                buttons(top)
                Text("Swipe right to approve · left to decline")
                    .font(.system(size: 12)).foregroundStyle(Theme.dim)
            } else {
                InboxZeroView(ownOnly: !inbox.queue.isEmpty, onShowList: onSelectMode,
                              onOpenThread: onOpenThread, onOpenBoard: onOpenBoard, onOpenHistory: onOpenHistory)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: feedback)
    }

    private func header(_ deck: [MediaRequest]) -> some View {
        let oldest = TriageFacts.oldestAge(deck)
        return HStack {
            (Text("\(deck.count)").fontWeight(.bold) + Text(" waiting" + (oldest.isEmpty ? "" : " · oldest \(oldest)")))
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.mut)
            Spacer()
            Button(action: onSelectMode) {
                Image(systemName: "checklist").font(.system(size: 16)).frame(width: 40, height: 40)
            }
            .accessibilityLabel("Select several")
        }
    }

    private func card(_ request: MediaRequest, position: Int, isTop: Bool) -> some View {
        let t = inbox.triage[request.id]
        let dx: CGFloat = isTop ? offset(request.id) : 0
        let canApprove = TriageFacts.loaded(t) && !TriageFacts.setupMissing(t)
        return SwipeCardView(request: request, triage: t, dragX: isTop ? dx : 0,
                             warning: isTop && inbox.armedId == request.id ? TriageFacts.lowSpaceMessage(t) : nil,
                             approveBlocked: !canApprove, onAdjust: { onAdjust(request) })
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

    private func dragGesture(_ request: MediaRequest, canApprove: Bool) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard flying == nil else { return }
                let crossed = abs(drag?.dx ?? 0) > Self.threshold
                drag = (request.id, value.translation.width)
                if crossed != (abs(value.translation.width) > Self.threshold),
                   value.translation.width < 0 || canApprove { feedback += 1 }
            }
            .onEnded { value in
                let dx = value.translation.width
                if abs(dx) > Self.threshold {
                    fly(request, right: dx > 0, canApprove: canApprove)
                } else {
                    withAnimation(.spring(duration: 0.3)) { drag = nil }
                }
            }
    }

    private func buttons(_ top: MediaRequest) -> some View {
        let t = inbox.triage[top.id]
        let canApprove = TriageFacts.loaded(t) && !TriageFacts.setupMissing(t)
        return HStack(spacing: 22) {
            circleButton("xmark", size: 58, tint: Theme.danger, label: "Decline") { fly(top, right: false, canApprove: canApprove) }
            circleButton("info", size: 44, tint: Theme.mut, label: "Details") { onDetails(top) }
            circleButton("checkmark", size: 58, tint: Theme.done, label: canApprove ? "Approve" : (TriageFacts.loaded(t) ? TriageFacts.setupMissingNote : "Checking space…")) {
                fly(top, right: true, canApprove: canApprove)
            }
            .disabled(!canApprove)
        }
    }

    private func circleButton(_ icon: String, size: CGFloat, tint: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .glassEffect(.regular.interactive(), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
        if right {
            inbox.approve(request, viewerId: viewerId)
        } else {
            inbox.decline(request, viewerId: viewerId)
        }
    }
}
