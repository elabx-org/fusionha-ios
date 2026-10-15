import SwiftUI
import FusionhaKit

/// One decision the inbox holds for five seconds before sending (web
/// `usePendingDecision`): Undo drops it before anything reaches the server.
struct InboxDecision: Equatable {
    enum Kind { case approve, decline }
    let kind: Kind
    let ids: [Int]
    let title: String
    let tiers: [QualityTier]
    var reason: RequestReason
}

/// The approver's triage inbox (web `useTriageInbox` + `useInboxActions`):
/// pending requests oldest-asked first, polled every 30 s, with each row's
/// triage facts fetched in chunks of 10 (re-asked every 3 s while metadata is
/// pending). A decision waits out the Undo, then goes through the plain
/// approve (`search: true`), reject (deferring "Not available yet") or bulk route.
@MainActor
@Observable
final class InboxModel {
    static let undoSeconds = 5.0

    private(set) var items: [MediaRequest] = []
    private(set) var triage: [Int: RequestTriage] = [:]
    private(set) var loaded = false
    private(set) var failed = false
    private(set) var pending: InboxDecision?
    private(set) var sending: Set<Int> = []
    /// The low-space approve that has been warned once ("Approve anyway").
    var armedId: Int?
    var selected: Set<Int> = []

    @ObservationIgnored private var undoTask: Task<Void, Never>?
    @ObservationIgnored private var client: APIClient?
    @ObservationIgnored private var onToast: ((String, String?, ToastVariant) -> Void)?

    /// Rows still waiting: decided ones stay out while their Undo runs or they send.
    var queue: [MediaRequest] {
        let hidden = Set(pending?.ids ?? []).union(sending)
        return items.filter { $0.status == "pending" && !hidden.contains($0.id) }
    }

    func bind(_ client: APIClient?, toast: @escaping (String, String?, ToastVariant) -> Void) {
        self.client = client
        self.onToast = toast
    }

    // MARK: Loading

    func poll() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: .seconds(30))
        }
    }

    func refresh() async {
        guard let client else { return }
        do {
            let page = try await client.requestsPage(view: "all", filter: nil, sort: "requested", limit: 50,
                                                     extra: [URLQueryItem(name: "status", value: "pending")])
            items = page.items
            failed = false
        } catch is CancellationError {
            return
        } catch {
            failed = true
        }
        loaded = true
        await loadTriage()
    }

    private func loadTriage() async {
        guard let client else { return }
        let ids = items.map(\.id)
        var pendingMeta = false
        for start in stride(from: 0, to: ids.count, by: 10) {
            let chunk = Array(ids[start..<min(start + 10, ids.count)])
            guard let rows = try? await client.requestTriage(ids: chunk) else { continue }
            for row in rows { triage[row.requestId] = row }
            pendingMeta = pendingMeta || rows.contains(where: \.metaPending)
        }
        if pendingMeta {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { await loadTriage() }
        }
    }

    // MARK: Deciding

    func isOwn(_ r: MediaRequest, viewerId: Int?) -> Bool { viewerId != nil && r.userId == viewerId }

    /// Approve waits for the row's triage; a low-space approve warns once first.
    /// Returns true when the decision was scheduled.
    @discardableResult
    func approve(_ r: MediaRequest, viewerId: Int?) -> Bool {
        let t = triage[r.id]
        guard !isOwn(r, viewerId: viewerId), TriageFacts.loaded(t), !TriageFacts.setupMissing(t) else { return false }
        if TriageFacts.lowSpaceMessage(t) != nil && armedId != r.id {
            armedId = r.id
            return false
        }
        schedule(InboxDecision(kind: .approve, ids: [r.id], title: title(r), tiers: r.tiers, reason: .notAvailableYet))
        return true
    }

    @discardableResult
    func decline(_ r: MediaRequest, viewerId: Int?) -> Bool {
        guard !isOwn(r, viewerId: viewerId) else { return false }
        schedule(InboxDecision(kind: .decline, ids: [r.id], title: title(r), tiers: [], reason: .notAvailableYet))
        return true
    }

    func bulk(_ kind: InboxDecision.Kind, reason: RequestReason = .other) {
        let ids = queue.map(\.id).filter { selected.contains($0) }
        guard !ids.isEmpty else { return }
        let only = ids.count == 1 ? items.first { $0.id == ids[0] } : nil
        selected = []
        schedule(InboxDecision(kind: kind, ids: ids, title: only.map(title) ?? "\(ids.count) requests", tiers: [], reason: reason))
    }

    /// Approve waits until every selected row's triage is in.
    var bulkChecking: Bool { selected.contains { triage[$0] == nil } }

    func setReason(_ reason: RequestReason) {
        guard pending?.kind == .decline else { return }
        pending?.reason = reason
    }

    func undo() {
        undoTask?.cancel()
        pending = nil
    }

    /// Sends the held decision now (a new decision, or leaving the inbox).
    func flush() {
        undoTask?.cancel()
        guard let decision = pending else { return }
        pending = nil
        sending.formUnion(decision.ids)
        Task { await commit(decision) }
    }

    private func schedule(_ decision: InboxDecision) {
        flush()
        armedId = nil
        pending = decision
        undoTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.undoSeconds))
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    private func commit(_ d: InboxDecision) async {
        defer { sending.subtract(d.ids) }
        guard let client else { return }
        let verb = d.kind == .approve ? "approve" : "decline"
        do {
            if d.ids.count == 1 {
                if d.kind == .approve {
                    try await client.approveRequest(id: d.ids[0], body: ApproveBody(editions: [], search: true))
                } else {
                    try await client.rejectRequest(id: d.ids[0], body: RejectBody(reason: d.reason, defer: d.reason == .notAvailableYet, note: nil))
                }
                items.removeAll { $0.id == d.ids[0] }
            } else {
                let action = d.kind == .approve ? "approve" : (d.reason == .notAvailableYet ? "defer" : "decline")
                let result = try await client.bulkDecide(RequestBulkBody(ids: d.ids, action: action,
                                                                         reason: d.kind == .approve ? nil : d.reason.rawValue,
                                                                         search: d.kind == .approve))
                let done = Set(result.results.filter(\.ok).map(\.id))
                items.removeAll { done.contains($0.id) }
                let failed = result.results.filter { !$0.ok }
                if !failed.isEmpty {
                    onToast?(TriageFacts.bulkFailureText(failed.map(\.error)),
                             "\(d.ids.count - failed.count) of \(d.ids.count) \(d.kind == .approve ? "approved" : "declined")", .warning)
                }
            }
        } catch {
            let api = error as? APIError
            var status: Int?
            if case .http(let code, _)? = api { status = code }
            onToast?(TriageFacts.failureMessage(code: api?.code, status: status), "Couldn’t \(verb) \(d.title)", .error)
        }
        await refresh()
    }

    func title(_ r: MediaRequest) -> String { r.title ?? "TMDB #\(r.tmdbId)" }
}
