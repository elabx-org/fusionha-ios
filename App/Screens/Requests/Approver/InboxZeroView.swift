import SwiftUI
import FusionhaKit

/// Nothing waiting (web `InboxZero` + `InboxCaughtUpDeck`): the check, the
/// "N in progress · N available · N declined" chips (to the Board or History)
/// and the three most recently decided requests. When only the viewer's own
/// requests wait, a calm note with a way to the list instead.
struct InboxZeroView: View {
    let ownOnly: Bool
    let onShowList: () -> Void
    let onOpenThread: (MediaRequest) -> Void
    let onOpenBoard: () -> Void
    let onOpenHistory: (HistoryFilter) -> Void
    @Environment(AppModel.self) private var model
    @State private var counts: RequestCounts?
    @State private var recent: [MediaRequest] = []

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Image(systemName: ownOnly ? "tray" : "checkmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(ownOnly ? Theme.mut : Theme.done)
                    .frame(width: 52, height: 52)
                    .background((ownOnly ? Theme.mut : Theme.done).opacity(0.15), in: Circle())
                    .symbolEffect(.bounce, value: ownOnly)
                Text(ownOnly ? "Only your own requests are waiting" : "Inbox zero 🎉")
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
                if ownOnly { Button("Show list", action: onShowList).font(.system(size: 14, weight: .semibold)) }
            }
            .padding(.top, 20)
            if !ownOnly {
                stats
                if !recent.isEmpty { recentList }
            }
        }
        .frame(maxWidth: .infinity)
        .task { await load() }
    }

    private var stats: some View {
        HStack(spacing: 8) {
            chip(counts?.active, "in progress", Theme.grab) { onOpenBoard() }
            chip(counts?.available, "available", Theme.done) { onOpenHistory(.available) }
            chip(counts?.declined, "declined", Theme.danger) { onOpenHistory(.declined) }
        }
    }

    private func chip(_ n: Int?, _ label: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            (Text("\(n ?? 0)").fontWeight(.bold) + Text(" \(label)"))
                .font(.system(size: 12.5))
                .foregroundStyle(tint)
                .padding(.horizontal, 10).frame(height: 30)
                .background(tint.opacity(0.13), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECENTLY DECIDED").font(.system(size: 11, weight: .bold)).tracking(0.8).foregroundStyle(Theme.dim)
            ForEach(recent) { r in
                Button { onOpenThread(r) } label: { RequestHistoryRow(request: r, compact: true) }
                    .buttonStyle(.plain)
            }
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        async let countsCall = try? client.requestCounts(view: "all")
        async let recentCall = try? client.requestsPage(view: "all", filter: nil, sort: "last_event", limit: 3)
        counts = await countsCall
        let decided: Set<String> = ["approved", "fulfilled", "rejected"]
        recent = (await recentCall)?.items.filter { decided.contains($0.status) } ?? []
    }
}

/// The 5 s Undo (web `UndoToast`): "Approving …" or "Declining … · reason",
/// nothing is sent until it closes.
struct InboxUndoToast: View {
    let decision: InboxDecision
    let onUndo: () -> Void
    let onReason: (RequestReason) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: decision.kind == .approve ? "checkmark" : "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(decision.kind == .approve ? Theme.done : Theme.danger)
            message.font(.system(size: 13.5)).foregroundStyle(Theme.txt).lineLimit(2)
            Spacer(minLength: 4)
            if decision.kind == .decline {
                Menu {
                    ForEach(RequestReason.allCases, id: \.self) { reason in
                        Button(reason.title) { onReason(reason) }
                    }
                } label: {
                    Text(decision.reason.title)
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .accessibilityLabel("Decline reason")
            }
            Button("Undo", action: onUndo).font(.system(size: 14, weight: .bold))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .glassEffect(.regular, in: Capsule())
        .padding(.horizontal, 12)
        .accessibilityElement(children: .contain)
    }

    private var message: Text {
        let tiers = decision.tiers.isEmpty ? "" : " · " + decision.tiers.map(\.chipLabel).joined(separator: " + ")
        switch decision.kind {
        case .approve:
            return decision.ids.count > 1
                ? Text("Approving ") + Text(decision.title).bold() + Text(" with each title’s usual setup")
                : Text("Approving ") + Text(decision.title).bold() + Text(tiers)
        case .decline:
            return Text("Declining ") + Text(decision.title).bold() + Text(" ·")
        }
    }
}
