import SwiftUI
import FusionhaKit

/// The approver's History (web `RequestsHistory`): All · Approved · Available
/// · Declined · Auto with a search; each row says who asked, who decided,
/// when, and how long it took to become available. Refreshes every 15 s.
struct RequestsHistoryView: View {
    let initialFilter: HistoryFilter
    let onOpenThread: (MediaRequest) -> Void
    @Environment(AppModel.self) private var model
    @State private var filter: HistoryFilter = .all
    @State private var query = ""
    @State private var items: [MediaRequest] = []
    @State private var cursor: String?
    @State private var loaded = false
    @State private var failed = false
    @State private var loadingMore = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DiscoverSegmented(options: HistoryFilter.allCases.map { ($0, $0.title) }, selection: $filter, fullTrack: true)
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 13)).foregroundStyle(Theme.dim)
                TextField("Filter by title or person", text: $query)
                    .font(.system(size: 14))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 12).frame(height: 38)
            .background(Theme.panel2, in: Capsule())
            content
        }
        .onAppear { filter = initialFilter }
        .task(id: "\(filter.rawValue)-\(query)") {
            items = []
            cursor = nil
            loaded = false
            if !query.isEmpty { try? await Task.sleep(for: .milliseconds(300)) }
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !loaded {
            DiscoverEmptyState(message: "Loading history…")
        } else if failed && items.isEmpty {
            DiscoverEmptyState(message: "Could not load history.")
        } else if items.isEmpty {
            DiscoverEmptyState(message: "No requests match.")
        } else {
            LazyVStack(spacing: 8) {
                ForEach(items) { r in
                    Button { onOpenThread(r) } label: { RequestHistoryRow(request: r) }.buttonStyle(.plain)
                }
                if cursor != nil {
                    Button(loadingMore ? "Loading…" : "Load more") { Task { await loadMore() } }
                        .buttonStyle(.discover(.subtle))
                        .disabled(loadingMore)
                }
            }
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        let q = filter.query(search: query.trimmingCharacters(in: .whitespaces))
        do {
            let page = try await client.requestsPage(view: "all", filter: q.filter, sort: "requested", limit: 30, extra: q.extra)
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
        let q = filter.query(search: query.trimmingCharacters(in: .whitespaces))
        guard let page = try? await client.requestsPage(view: "all", filter: q.filter, sort: "requested", limit: 30,
                                                        cursor: cursor, extra: q.extra) else { return }
        let known = Set(items.map(\.id))
        items += page.items.filter { !known.contains($0.id) }
        self.cursor = page.nextCursor
    }
}

/// One decided request (web `HistoryRow` / `RecentlyDecided`): poster, title,
/// tiers, "Requested by · approved by · when", the status pill and the time
/// to available. `compact` is the inbox-zero list's shorter row.
struct RequestHistoryRow: View {
    let request: MediaRequest
    var compact = false

    var body: some View {
        let title = request.title ?? "TMDB #\(request.tmdbId)"
        let pill = RequestBoard.historyPill(request)
        HStack(alignment: .top, spacing: 10) {
            ActPoster(url: request.poster, title: title, size: .sm)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    (Text(title).fontWeight(.semibold) + Text(verbatim: request.year.map { " (\($0))" } ?? "").foregroundColor(Theme.mut))
                        .font(.system(size: 14)).foregroundStyle(Theme.txt).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(pill.label)
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(pill.tone.color)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(pill.tone.color.opacity(0.15), in: Capsule())
                        .fixedSize()
                }
                HStack(spacing: 5) {
                    ForEach(request.tiers, id: \.self) { ActTierChip(tier: $0) }
                    if !compact && request.availableAt != nil {
                        Label(RequestBoard.timeToAvailable(request), systemImage: "timer")
                            .font(.system(size: 11.5).monospacedDigit()).foregroundStyle(Theme.mut)
                            .accessibilityLabel("Time to available \(RequestBoard.timeToAvailable(request))")
                    }
                }
                Text(metaLine).font(.system(size: 12)).foregroundStyle(Theme.mut).lineLimit(2)
            }
            Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 13)).foregroundStyle(Theme.dim)
                .padding(.top, 2)
                .accessibilityHidden(true)
        }
        .padding(10)
        .actWash(RequestLifecycle.wash(status: request.status, lifecycle: request.lifecycle ?? []).color, radius: 14, base: Theme.card)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the conversation")
    }

    /// "Requested by Sam · approved by Ana · 2 days ago", a dot only between parts that show.
    private var metaLine: String {
        var parts: [String] = []
        if let who = request.requester?.displayName { parts.append("\(compact ? "Asked" : "Requested") by \(who)") }
        if let by = request.approvedBy {
            parts.append(by.kind == "auto" ? RequestLifecycle.autoText(by) : "approved by \(by.displayName ?? "an admin")")
        } else if let by = request.declinedBy {
            parts.append("declined by \(by.displayName)")
        }
        let when = ActFmt.relative(compact ? (request.decidedAt ?? request.availableAt ?? request.requestedAt) : request.requestedAt)
        if !when.isEmpty { parts.append(when) }
        return parts.joined(separator: " · ")
    }
}
