import SwiftUI
import FusionhaKit

/// The approver's History (Final mock): rows grouped by the day they were
/// decided, the status as a coloured word, the time on the right. Status,
/// search and source live in the filter sheet. Refreshes every 15 s.
struct RequestsHistoryView: View {
    let onOpenThread: (MediaRequest) -> Void
    @Environment(AppModel.self) private var model
    @Environment(RequestsNav.self) private var nav
    @State private var items: [MediaRequest] = []
    @State private var cursor: String?
    @State private var loaded = false
    @State private var failed = false
    @State private var loadingMore = false

    private var values: RequestsFilter.Values { nav.filter[.history] }

    /// Loaded rows decided this calendar month (newest first, so the first
    /// page covers the month unless it is a very busy one).
    private var thisMonth: Int {
        items.filter { RequestHistoryDays.instant($0).map { Calendar.current.isDate($0, equalTo: Date(), toGranularity: .month) } ?? false }.count
    }
    private var key: String { "\(values.status.rawValue)|\(values.search)|\(nav.filter.query(.history))" }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            RequestsViewHeader {
                if loaded { requestsCount(thisMonth, "decided this month") }
            }
            content
        }
        .task(id: key) {
            items = []
            cursor = nil
            loaded = false
            if !values.search.isEmpty { try? await Task.sleep(for: .milliseconds(300)) }
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(for: .seconds(15))
            }
        }
        .onChange(of: items) {
            nav.remember(items)
            nav.resultCount = items.count
        }
    }

    @ViewBuilder
    private var content: some View {
        if !loaded {
            DiscoverEmptyState(message: "Loading history…")
        } else if failed && items.isEmpty {
            DiscoverEmptyState(message: "Could not load history.")
        } else if items.isEmpty {
            DiscoverEmptyState(message: nav.filter.activeCount(.history) > 0 ? "Nothing decided with these filters." : "Nothing decided yet.")
        } else {
            let byId = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(RequestHistoryDays.group(items), id: \.title) { day in
                    RequestsSectionHeader(title: day.title)
                    RequestsGroup {
                        ForEach(day.ids.compactMap { byId[$0] }) { r in
                            Button { onOpenThread(r) } label: { row(r) }.buttonStyle(.plain)
                        }
                    }
                }
                if cursor != nil {
                    Button(loadingMore ? "Loading…" : "Load more") { Task { await loadMore() } }
                        .buttonStyle(.discover(.subtle))
                        .disabled(loadingMore)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 14)
                }
            }
        }
    }

    private func row(_ r: MediaRequest) -> some View {
        let word = HistoryWord(r)
        return RequestsListRow(request: r, compact: false) {
            HStack(spacing: 6) {
                Text(word.text).fontWeight(.semibold).foregroundStyle(word.color)
                Text(meta(r)).lineLimit(1)
            }
        } trailing: {
            Text(RequestHistoryDays.time(RequestHistoryDays.instant(r)))
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(Theme.dim)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the conversation")
    }

    /// "sam · Letterboxd".
    private func meta(_ r: MediaRequest) -> String {
        [r.requester?.displayName, RequestOrigin.word(r.source)].compactMap { $0 }.joined(separator: " · ")
    }

    private func load() async {
        guard let client = model.client else { return }
        let q = values.status.query(search: values.search.trimmingCharacters(in: .whitespaces))
        do {
            let page = try await client.requestsPage(view: "all", filter: q.filter, sort: "requested", limit: 30,
                                                     extra: q.extra + nav.filter.query(.history))
            let firstIds = Set(page.items.map(\.id))
            let beyond = items.count > page.items.count ? items.dropFirst(page.items.count).filter { !firstIds.contains($0.id) } : []
            if loaded && !beyond.isEmpty { items = page.items + beyond } else { items = page.items; cursor = page.nextCursor }
            failed = false
        } catch is CancellationError {
            return
        } catch {
            failed = true
        }
        loaded = true
    }

    private func loadMore() async {
        guard let client = model.client, let cursor else { return }
        loadingMore = true
        defer { loadingMore = false }
        let q = values.status.query(search: values.search.trimmingCharacters(in: .whitespaces))
        guard let page = try? await client.requestsPage(view: "all", filter: q.filter, sort: "requested", limit: 30,
                                                        cursor: cursor, extra: q.extra + nav.filter.query(.history)) else { return }
        let known = Set(items.map(\.id))
        items += page.items.filter { !known.contains($0.id) }
        self.cursor = page.nextCursor
    }
}

/// A decided request's status as one coloured word: approvals in the accent
/// (the word says which), Available green, Declined red (Final mock).
struct HistoryWord {
    let text: String
    let color: Color

    init(_ r: MediaRequest) {
        let pill = RequestBoard.historyPill(r)
        text = pill.label == "Approved" && r.approvedBy?.kind == "auto" ? "Auto-approved" : pill.label
        switch r.status {
        case "fulfilled": color = Theme.done
        case "rejected", "deferred": color = Theme.danger
        case "approved": color = pill.tone == .grab ? Theme.grab : Theme.accentText
        default: color = pill.tone.color
        }
    }
}
