import SwiftUI
import FusionhaKit

/// "Select several" (web `TriageInboxList` stacked + `BulkBar`): every waiting
/// request as a row with a checkbox (own requests show, but can't be picked
/// unless the viewer is an admin);
/// a tap opens its card; the bulk bar declines with one reason or approves
/// with each title's usual setup. On a hardware keyboard J / K move a focus
/// ring, X selects, Return opens the title, and A / D open the card first
/// (web L11), where they decide.
struct InboxListView: View {
    let inbox: InboxModel
    let viewerId: Int?
    let onOpen: (MediaRequest) -> Void
    let onOpenTitle: (MediaRequest) -> Void
    let onBackToCards: () -> Void
    @State private var focus = TriageQueueFocus()
    /// The ring shows once the keyboard is in use, never for touch alone.
    @State private var keyed = false
    @Environment(DiscoverStore.self) private var store

    var body: some View {
        VStack(spacing: 10) {
            // The count and "Done" (back to cards) live in the shared header row.
            LazyVStack(spacing: 8) {
                ForEach(inbox.queue) { r in row(r).id(Self.rowId(r.id)) }
            }
            if !inbox.selected.isEmpty {
                InboxBulkBar(inbox: inbox).padding(.top, 6)
            }
        }
        .triageKeys(on: .list, perform: key)
    }

    static func rowId(_ id: Int) -> String { "inbox-row-\(id)" }

    private func key(_ action: TriageKeys.Action) -> Bool {
        let order = inbox.queue.map(\.id)
        guard let id = focus.effective(order), let request = inbox.queue.first(where: { $0.id == id }) else { return false }
        keyed = true
        switch action {
        case .approve, .decline: onOpen(request)
        case .next, .prev:
            focus.move(action == .next ? 1 : -1, in: order)
            // The rows live in Discover's page scroll: reveal the new focus there.
            if let next = focus.focusId { store.scrollReveal = Self.rowId(next) }
        case .toggle:
            if inbox.selected.contains(id) {
                inbox.selected.remove(id)
            } else if !inbox.isLocked(request, viewerId: viewerId) {
                inbox.selected.insert(id)
            }
        case .open: onOpenTitle(request)
        }
        return true
    }

    /// One row at the 0.4.214 card scale: a 22 pt checkbox in a 44 pt tap
    /// area, the 44 pt 2:3 poster, title 14 / meta 12.5 / time 11.5 pt, the
    /// requester's 20 pt avatar and the source's 22 pt mark.
    private func row(_ r: MediaRequest) -> some View {
        let own = inbox.isOwn(r, viewerId: viewerId)
        let locked = inbox.isLocked(r, viewerId: viewerId)
        let on = inbox.selected.contains(r.id)
        let title = r.title ?? "TMDB #\(r.tmdbId)"
        return HStack(spacing: 12) {
            Button {
                if on { inbox.selected.remove(r.id) } else if !locked { inbox.selected.insert(r.id) }
            } label: {
                WebCheckSquare(checked: on, size: 22).frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(locked)
            .accessibilityLabel("Select \(title)")
            .accessibilityAddTraits(on ? .isSelected : [])
            Button { onOpen(r) } label: {
                HStack(spacing: 12) {
                    RequestRowPoster(url: r.poster, title: title)
                    rowText(r, title: title, own: own)
                    Spacer(minLength: 0)
                    RequestSourceMark(kind: r.source?.kind)
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.dim)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        // 16 pt to the visible checkbox: its 44 pt tap area overhangs by 11.
        .padding(.vertical, 14).padding(.leading, 5).padding(.trailing, 16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            if keyed && focus.effective(inbox.queue.map(\.id)) == r.id {
                RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.i1.opacity(0.45), lineWidth: 1.5)
            }
        }
    }

    private func rowText(_ r: MediaRequest, title: String, own: Bool) -> some View {
        let name = TriageFacts.requesterName(r)
        return VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
            HStack(spacing: 5) {
                ForEach(r.tiers, id: \.self) { RequestRowTierChip(tier: $0) }
                Text(RequestLifecycle.kindLabel(r)).font(.system(size: 12.5)).foregroundStyle(Theme.mut).lineLimit(1)
            }
            HStack(spacing: 6) {
                RequestAvatar(name: name)
                Text("\(TriageFacts.firstName(name))\(own ? " (you)" : "")")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.mut).lineLimit(1)
                Text("· \(TriageFacts.compactAge(r.requestedAt))")
                    .font(.system(size: 11.5)).foregroundStyle(Theme.dim).lineLimit(1)
            }
        }
    }
}

/// "N selected · Decline · Approve with defaults" (web `BulkBar`). Decline asks
/// for one reason; a selection that won't fit warns first ("Approve anyway").
struct InboxBulkBar: View {
    let inbox: InboxModel
    @State private var spaceWarned = false

    var body: some View {
        let lowSpace = TriageFacts.bulkLowSpace(inbox.triage, ids: Array(inbox.selected))
        VStack(alignment: .leading, spacing: 8) {
            if spaceWarned, let lowSpace {
                Text(lowSpace).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.txt)
                    .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                    .actWash(Theme.miss, radius: 10, base: Theme.panel2)
            }
            HStack(spacing: 8) {
                (Text("\(inbox.selected.count)").fontWeight(.bold) + Text(" selected"))
                    .font(.system(size: 13.5)).foregroundStyle(Theme.txt)
                Spacer(minLength: 4)
                Menu {
                    ForEach(RequestReason.allCases, id: \.self) { reason in
                        Button(reason.title) { inbox.bulk(.decline, reason: reason) }
                    }
                } label: {
                    Label("Decline", systemImage: "xmark").font(.system(size: 13.5, weight: .semibold))
                }
                .accessibilityHint("Pick a reason")
                Button {
                    if lowSpace != nil && !spaceWarned { spaceWarned = true } else { inbox.bulk(.approve) }
                } label: {
                    Text(inbox.bulkChecking ? "Checking space…" : (spaceWarned && lowSpace != nil ? "Approve anyway" : "Approve with defaults"))
                }
                .buttonStyle(.discover(.primary))
                .disabled(inbox.bulkChecking)
                Button { inbox.selected = [] } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).frame(width: 36, height: 44)
                }
                .accessibilityLabel("Clear selection")
            }
        }
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onChange(of: inbox.selected) { spaceWarned = false }
    }
}
