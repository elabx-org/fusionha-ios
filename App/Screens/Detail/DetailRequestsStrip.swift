import SwiftUI
import FusionhaKit

/// A5 on a title's page (web `RequestsStrip`): everyone who asked, what each
/// asked for, the status, where from and who approved it; a row opens its
/// thread. Approvers get "Message all" for the open requests. Hidden for a
/// request-scoped viewer and when nobody asked.
struct DetailRequestsStrip: View {
    let itemId: Int
    @Environment(AppModel.self) private var model
    @Environment(DetailStore.self) private var store
    @State private var thread: MediaRequest?
    @State private var composing = false

    private var visible: Bool { model.me != nil && !model.requestScoped }
    private var canApprove: Bool { model.me?.hasPermission("requests.approve") ?? false }

    var body: some View {
        Group {
            if visible && !store.requestRows.isEmpty {
                let rows = store.requestRows
                let requests = rows.map(\.request)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Label("Requests", systemImage: "person.2").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
                        Text(RequestItemStrip.summary(requests)).font(.system(size: 12)).foregroundStyle(Theme.mut).lineLimit(2)
                        Spacer(minLength: 0)
                        if canApprove && requests.contains(where: RequestItemStrip.isOpen) {
                            Button("Message all", systemImage: "bubble.left.and.bubble.right") { composing = true }
                                .labelStyle(.iconOnly)
                                .frame(width: 44, height: 44)
                                .foregroundStyle(Theme.txt)
                        }
                    }
                    ForEach(rows) { row in rowView(row) }
                }
                .padding(14)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            }
        }
        .task(id: itemId) { await load() }
        .sheet(item: $thread) { r in RequestThreadSheet(request: r) { Task { await load() } } }
        .sheet(isPresented: $composing) { BroadcastSheet(itemId: itemId) }
    }

    private func rowView(_ row: ItemRequestRow) -> some View {
        let r = row.request
        let others = (row.joiners ?? []).filter { $0.id == nil || $0.id != r.requester?.id }
        return Button { thread = r } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(r.requester?.displayName ?? "Another requester").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                    ForEach(r.tiers, id: \.self) { ActTierChip(tier: $0) }
                    Spacer(minLength: 0)
                    Text(RequestBoard.statusLabel(r.status)).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut)
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.dim)
                }
                Text([RequestLifecycle.sourceText(r.source), RequestItemStrip.approvedText(r.approvedBy),
                      ServerTime.parse(r.requestedAt).map { $0.formatted(date: .abbreviated, time: .shortened) }]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 12)).foregroundStyle(Theme.mut).lineLimit(2)
                if !others.isEmpty {
                    Text("+ " + others.map(\.displayName).joined(separator: ", ") + " asked too")
                        .font(.system(size: 12)).foregroundStyle(Theme.i2).lineLimit(1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the request")
    }

    private func load() async {
        guard visible, let client = model.client else { return }
        store.requestRows = (try? await client.itemRequests(itemId: itemId)) ?? store.requestRows
    }
}

/// "Message everyone who asked": one line to every open request thread.
private struct BroadcastSheet: View {
    let itemId: Int
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var sending = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Message", text: $text, axis: .vertical).lineLimit(3...6)
                        .onChange(of: text) { if text.count > 2000 { text = String(text.prefix(2000)) } }
                } footer: {
                    Text("Posted to every open request thread for this title.")
                }
            }
            .navigationTitle("Message everyone who asked")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(sending ? "Sending…" : "Send") { Task { await send() } }
                        .disabled(sending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func send() async {
        guard let client = model.client else { return }
        sending = true
        defer { sending = false }
        do {
            let n = try await client.broadcastRequests(mediaItemId: itemId, body: text.trimmingCharacters(in: .whitespacesAndNewlines))
            model.toast("Sent to \(n) \(n == 1 ? "thread" : "threads")")
            dismiss()
        } catch {
            model.toast(ErrorCopy.message(for: error, fallback: "No open requests to message"), title: "Could not send", variant: .error)
        }
    }
}
