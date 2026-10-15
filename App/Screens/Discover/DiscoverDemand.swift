import SwiftUI
import FusionhaKit

/// Per-title request demand for the Discover cards a requester sees, fetched
/// in batches (one `/requests/demand` call per kind for every card that
/// appeared within a moment), like the web's per-rail query.
@MainActor
@Observable
final class DiscoverDemand {
    private(set) var byKey: [String: RequestTitleDemand] = [:]
    @ObservationIgnored private var asked: Set<String> = []
    @ObservationIgnored private var pending: [MediaKind: Set<Int>] = [:]
    @ObservationIgnored private var flushing = false

    private static func key(_ kind: MediaKind, _ id: Int) -> String { "\(kind.rawValue)-\(id)" }

    func get(_ kind: MediaKind, _ id: Int) -> RequestTitleDemand? { byKey[Self.key(kind, id)] }

    /// A card appeared: fetch its demand with the others that appear with it.
    func want(_ client: APIClient?, kind: MediaKind, id: Int) {
        guard let client, asked.insert(Self.key(kind, id)).inserted else { return }
        pending[kind, default: []].insert(id)
        guard !flushing else { return }
        flushing = true
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            let batch = pending
            pending = [:]
            flushing = false
            for (kind, ids) in batch {
                for chunk in Array(ids).chunked(100) { await fetch(client, kind: kind, ids: chunk) }
            }
        }
    }

    /// Re-reads one title after a join or leave.
    func refresh(_ client: APIClient?, kind: MediaKind, id: Int) async {
        guard let client else { return }
        await fetch(client, kind: kind, ids: [id])
    }

    /// Everything again (a request was made or withdrawn elsewhere).
    func reset() {
        byKey = [:]
        asked = []
    }

    private func fetch(_ client: APIClient, kind: MediaKind, ids: [Int]) async {
        guard let rows = try? await client.requestDemand(kind: kind, tmdbIds: ids) else {
            for id in ids { asked.remove(Self.key(kind, id)) }
            return
        }
        for row in rows { byKey[Self.key(kind, row.tmdbId)] = row }
    }
}

private extension Array {
    func chunked(_ size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}

/// The row under a requester's card (web `CardDemandRow` / `MeTooButton`):
/// Me too joins in place, Joined offers Leave, Watch and "Request HD" open
/// the request sheet.
struct DiscoverCardDemandRow: View {
    let result: MediaSearchResult
    let demand: RequestTitleDemand
    let row: DiscoverCardDemand.Row
    @Environment(AppModel.self) private var model
    @Environment(DiscoverStore.self) private var store
    @State private var working = false

    var body: some View {
        switch row {
        case .meToo where demand.state == "joined":
            Menu {
                Button(role: .destructive) { Task { await leave() } } label: {
                    Label("Leave request", systemImage: "xmark")
                }
                Text("You stop getting updates.")
            } label: {
                chip(icon: nil, text: "Joined · \(demand.asked) asked", tint: Theme.i2, chevron: true)
            }
            .accessibilityLabel("Joined · \(demand.asked) asked · \(result.title)")
        case .meToo:
            Button { Task { await join() } } label: {
                chip(icon: nil, text: "Me too · \(demand.asked) asked", tint: Theme.i2, chevron: false)
            }
            .buttonStyle(.plain)
            .disabled(working)
            .accessibilityLabel("Me too · \(demand.asked) asked · \(result.title)")
        case .watch, .requestTiers:
            let label = row == .watch ? "Watch" : DiscoverCardDemand.requestTiersLabel(demand.requestableTiers)
            Button { store.requestPick = result } label: {
                chip(icon: row == .watch ? "eye" : "plus", text: label, tint: Theme.mut, chevron: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(label) · \(result.title)")
        }
    }

    private func chip(icon: String?, text: String, tint: Color, chevron: Bool) -> some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon).font(.system(size: 10, weight: .bold))
            } else {
                RequestAnonStack(count: demand.asked, size: 16)
            }
            Text(text).lineLimit(1)
            if chevron { Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)) }
        }
        .font(.system(size: 11.5, weight: .semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(tint.opacity(0.13), in: Capsule())
        .contentShape(Capsule())
    }

    private func join() async {
        guard let client = model.client else { return }
        working = true
        defer { working = false }
        do {
            try await client.submitRequest(RequestCreateBody(tmdbId: result.tmdbId, kind: result.kind,
                                                             editions: demand.joinableTiers, join: true))
            DiscoverToasts.shared.show(.success, RequestOffer.joinedToast)
            await store.demand.refresh(client, kind: result.kind, id: result.tmdbId)
        } catch {
            DiscoverToasts.shared.error("Could not join", error)
        }
    }

    private func leave() async {
        guard let client = model.client, let id = demand.requestId else { return }
        do {
            try await client.leaveRequest(id: id)
            DiscoverToasts.shared.show(.success, "Left the request")
            await store.demand.refresh(client, kind: result.kind, id: result.tmdbId)
        } catch {
            DiscoverToasts.shared.error("Could not leave", error)
        }
    }
}
