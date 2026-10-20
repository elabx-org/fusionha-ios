import SwiftUI
import FusionhaKit

/// The wide Inbox (web `TriageInboxList` in `panes` mode, mock `.tri`): the
/// queue on the leading side (294–380 wide), every row with its checkbox, and
/// the focused request's aside beside it (`InboxAsideView`; Details opens the
/// full decision card as a sheet). Each side scrolls on its own and the page
/// doesn't. Focus starts on the first row and, after a decision, moves to the
/// row that took its place (web `effectiveFocus`). The bulk bar sits under
/// the queue. On a hardware keyboard A / D decide the focused request, J / K
/// move the focus, X selects it and Return opens its title (`triageKeys`).
struct InboxPanesView: View {
    let inbox: InboxModel
    let viewerId: Int?
    let onAdjust: (MediaRequest) -> Void
    let onDetails: (MediaRequest) -> Void
    let onOpenTitle: (MediaRequest) -> Void
    @State private var focus = TriageQueueFocus()

    private var focused: MediaRequest? {
        let queue = inbox.queue
        guard let id = focus.effective(queue.map(\.id)) else { return nil }
        return queue.first { $0.id == id }
    }

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .top, spacing: 18) {
                queue.frame(width: Self.queueWidth(proxy.size.width))
                card.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .triageKeys(on: .panes, perform: key)
    }

    /// The web's `minmax(294px, 380px)`, `minmax(294px, 320px)` at 1100 and below.
    static func queueWidth(_ width: CGFloat) -> CGFloat {
        let cap: CGFloat = width + RequestsWideRule.margins > 1100 ? 380 : 320
        return min(cap, max(294, width * 0.36))
    }

    private var queue: some View {
        VStack(spacing: 8) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(inbox.queue) { r in
                            InboxQueueRow(request: r, inbox: inbox, viewerId: viewerId, focused: r.id == focused?.id) {
                                focus.focus(r.id, in: inbox.queue.map(\.id))
                            }
                            .id(r.id)
                        }
                    }
                    .padding(.bottom, 8)
                }
                .scrollIndicators(.hidden)
                // J / K keep the focused row in view (web `reveal`).
                .onChange(of: focus) { if let id = focus.focusId { proxy.scrollTo(id) } }
            }
            if !inbox.selected.isEmpty {
                InboxBulkBar(inbox: inbox)
            }
        }
    }

    @ViewBuilder
    private var card: some View {
        if let request = focused {
            ScrollView {
                InboxAsideView(
                    request: request, triage: inbox.triage[request.id], own: inbox.isLocked(request, viewerId: viewerId),
                    armed: inbox.armedId == request.id,
                    onApprove: { _ = inbox.approve(request, viewerId: viewerId) },
                    onDecline: { _ = inbox.decline(request, viewerId: viewerId) },
                    onAdjust: { onAdjust(request) },
                    onDetails: { onDetails(request) })
                .id(request.id)
                .transition(.opacity)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .animation(.snappy(duration: 0.2), value: request.id)
        }
    }

    /// The keys act through the same decide, Undo and selection as the buttons.
    private func key(_ action: TriageKeys.Action) -> Bool {
        guard let request = focused else { return false }
        switch action {
        case .approve: inbox.approve(request, viewerId: viewerId)
        case .decline: inbox.decline(request, viewerId: viewerId)
        case .next, .prev:
            inbox.armedId = nil
            focus.move(action == .next ? 1 : -1, in: inbox.queue.map(\.id))
        case .toggle:
            if inbox.selected.contains(request.id) {
                inbox.selected.remove(request.id)
            } else if !inbox.isLocked(request, viewerId: viewerId) {
                inbox.selected.insert(request.id)
            }
        case .open: onOpenTitle(request)
        }
        return true
    }
}

/// One queue row (web `TriageQueueRow`, mock `.qrow`): checkbox, poster,
/// "Title (year)", who · tiers · source · age. The row focuses its card; the
/// checkbox only selects. Focus is a selection state: the accent ghost.
struct InboxQueueRow: View {
    let request: MediaRequest
    let inbox: InboxModel
    let viewerId: Int?
    let focused: Bool
    let onFocus: () -> Void

    var body: some View {
        let locked = inbox.isLocked(request, viewerId: viewerId)
        let on = inbox.selected.contains(request.id)
        let title = request.title ?? "TMDB #\(request.tmdbId)"
        HStack(spacing: 10) {
            Button {
                if on { inbox.selected.remove(request.id) } else if !locked { inbox.selected.insert(request.id) }
            } label: {
                WebCheckSquare(checked: on, size: 22).frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(locked)
            .accessibilityLabel("Select \(title)")
            .accessibilityAddTraits(on ? .isSelected : [])
            Button(action: onFocus) {
                HStack(spacing: 10) {
                    RequestRowPoster(url: request.poster, title: title)
                    text(title)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(focused ? .isSelected : [])
        }
        .padding(.vertical, 10).padding(.leading, 2).padding(.trailing, 12)
        .background(focused ? Theme.i1.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(focused ? Theme.i1.opacity(0.45) : Theme.line))
    }

    private func text(_ title: String) -> some View {
        let name = TriageFacts.requesterName(request)
        let own = inbox.isOwn(request, viewerId: viewerId)
        return VStack(alignment: .leading, spacing: 5) {
            (Text(title).fontWeight(.semibold) + Text(verbatim: request.year.map { " (\($0))" } ?? "").foregroundColor(Theme.mut))
                .font(.system(size: 14)).foregroundStyle(Theme.txt).lineLimit(1)
            HStack(spacing: 6) {
                RequestAvatar(name: name)
                Text("\(TriageFacts.firstName(name))\(own ? " (you)" : "")").lineLimit(1)
                ForEach(request.tiers, id: \.self) { RequestRowTierChip(tier: $0) }
                Text("\(RequestOrigin.word(request.source)) · \(TriageFacts.compactAge(request.requestedAt))").lineLimit(1)
            }
            .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            if let held = request.held {
                Label(held.label, systemImage: "hand.raised.fill")
                    .font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.miss).lineLimit(1)
            }
        }
    }
}
