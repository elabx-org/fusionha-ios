import SwiftUI
import FusionhaKit

/// Inbox as a list (Proposal 2, approved 2026-10-19): the Board's Pending
/// rows in one grouped list. Swipe right approves and left declines (with
/// Undo), a short swipe shows the buttons, hold for the menu, tap for the
/// decision card. "Select" in the header switches to the checkbox list.
struct InboxRowsView: View {
    let inbox: InboxModel
    let viewerId: Int?
    let onOpen: (MediaRequest) -> Void
    let onDeclineWithReason: (MediaRequest) -> Void
    @Environment(AppModel.self) private var model
    @Environment(RequestsNav.self) private var nav

    var body: some View {
        let queue = inbox.queue
        let shared = RequestStageFacts.sharedRequester(queue)
        VStack(alignment: .leading, spacing: 4) {
            if let shared {
                RequestsSectionHeader(title: "All by \(shared)")
            }
            RequestsGroup {
                ForEach(queue) { r in
                    let line = BoardStageRow(request: r, column: .pending, showRequester: shared == nil,
                                             compact: nav.filter[.inbox].compact)
                    if inbox.isLocked(r, viewerId: viewerId) {
                        Button { onOpen(r) } label: { line }.buttonStyle(.plain)
                    } else {
                        BoardSwipeRow(onApprove: { approve(r) }, onDecline: { _ = inbox.decline(r, viewerId: viewerId) },
                                      onDeclineWithReason: { onDeclineWithReason(r) }) {
                            Button { onOpen(r) } label: { line }.buttonStyle(.plain)
                        }
                        .contextMenu {
                            BoardRowMenu(request: r, onApprove: { _ = approve(r) }, onDecline: { onDeclineWithReason(r) },
                                         onThread: { onOpen(r) })
                        }
                    }
                }
            }
        }
    }

    /// Approve needs the row's triage; a low-space approve warns once.
    private func approve(_ r: MediaRequest) -> Bool {
        if inbox.approve(r, viewerId: viewerId) { return true }
        if let warning = TriageFacts.lowSpaceMessage(inbox.triage[r.id]), inbox.armedId == r.id {
            model.toast("\(warning) Swipe again to approve anyway.", title: nil, variant: .warning)
        } else if !TriageFacts.loaded(inbox.triage[r.id]) {
            model.toast("Checking free space. Try again in a moment.", title: nil, variant: .info)
        }
        return false
    }
}
