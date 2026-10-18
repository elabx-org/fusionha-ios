import SwiftUI
import FusionhaKit

/// The requester's list (web R1 "My requests"): the quota meter, an Active ·
/// Available · All filter with counts, the "From source" filter (Plex and
/// Letterboxd, fusionha 0.4.209 / 0.4.213), the live request cards (newest
/// activity first, cursor-paged) and Load more. Polls every 15 s while open
/// and shows the last list from this phone's cache straight away.
struct MyRequestsView: View {
    enum Filter: String, CaseIterable, Hashable {
        case active, available, all

        var title: String {
            switch self {
            case .active: return "Active"
            case .available: return "Available"
            case .all: return "All"
            }
        }

        var empty: String {
            switch self {
            case .active: return "Nothing on its way right now."
            case .available: return "Nothing available yet."
            case .all: return "You haven't requested anything yet."
            }
        }

        func count(_ counts: RequestCounts?) -> Int? {
            guard let counts else { return nil }
            switch self {
            case .active: return counts.active
            case .available: return counts.available
            case .all: return counts.all
            }
        }
    }

    @Environment(AppModel.self) private var model
    @Environment(DiscoverStore.self) private var store
    @State private var filter: Filter = .active
    @State private var items: [MediaRequest] = []
    @State private var cursor: String?
    @State private var counts: RequestCounts?
    @State private var source: RequestSourceFilter?
    /// The unfiltered `by_source` buckets the source chips count from.
    @State private var bySource: [RequestSourceCount] = []
    @State private var quota: RequestQuota?
    @State private var plexLinks: [Int: String] = [:]
    @State private var loaded = false
    @State private var failed = false
    @State private var loadingMore = false
    @State private var thread: MediaRequest?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let quota { RequestQuotaMeter(quota: quota) }
            DiscoverSegmented(options: Filter.allCases.map { f -> (Filter, String) in
                (f, f.count(counts).map { $0 > 0 ? "\(f.title) \($0)" : f.title } ?? f.title)
            }, selection: $filter, fullTrack: true)
            RequestSourceFilterBar(bySource: bySource, value: $source)
            content
        }
        .task(id: "\(filter.rawValue)-\(store.requestsVersion)-\(sourceKey)") { await poll() }
        .sheet(item: $thread) { request in
            RequestThreadSheet(request: request) { Task { await refresh() } }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !loaded {
            DiscoverEmptyState(message: "Loading your requests…")
        } else if failed && items.isEmpty {
            DiscoverEmptyState(message: "Could not load your requests.")
        } else if items.isEmpty {
            DiscoverEmptyState(message: source != nil ? "Nothing from this source matches this filter." : filter.empty)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, request in
                    RequestCardView(request: request, plexURL: plexLinks[request.id],
                                    onOpenThread: { thread = request },
                                    onChanged: { Task { await refresh() } })
                        .discoverReveal(index: index)
                }
                if cursor != nil {
                    Button(loadingMore ? "Loading…" : "Load more") { Task { await loadMore() } }
                        .buttonStyle(.discover(.subtle))
                        .disabled(loadingMore)
                        .padding(.top, 4)
                }
            }
        }
    }

    // MARK: Loading

    private var sourceQuery: [URLQueryItem] { source?.query ?? [] }
    private var sourceKey: String { sourceQuery.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&") }

    private func poll() async {
        guard let client = model.client else { return }
        items = []
        cursor = nil
        loaded = false
        let extra = sourceQuery
        if let page = await client.cached({ try await $0.requestsPage(view: "mine", filter: filter.rawValue, extra: extra) }) {
            items = page.items
            cursor = page.nextCursor
            loaded = true
        }
        counts = await client.cached { try await $0.requestCounts(view: "mine", extra: extra) } ?? counts
        if extra.isEmpty { bySource = counts?.bySource ?? bySource }
        quota = await client.cached { try await $0.requestQuota() } ?? quota
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: .seconds(15))
        }
    }

    /// Re-reads the first page (keeping any pages already loaded beyond it), the counts and the quota.
    private func refresh() async {
        guard let client = model.client else { return }
        do {
            let extra = sourceQuery
            async let pageCall = client.requestsPage(view: "mine", filter: filter.rawValue, extra: extra)
            async let countsCall = try? client.requestCounts(view: "mine", extra: extra)
            async let allCall = try? client.requestCounts(view: "mine")
            async let quotaCall = try? client.requestQuota()
            let page = try await pageCall
            let firstIds = Set(page.items.map(\.id))
            let beyond = items.dropFirst(page.items.count).filter { !firstIds.contains($0.id) }
            items = page.items + beyond
            if beyond.isEmpty { cursor = page.nextCursor }
            counts = await countsCall ?? counts
            if let all = await allCall { bySource = all.bySource ?? [] }
            quota = await quotaCall
            failed = false
        } catch is CancellationError {
            return
        } catch {
            failed = true
        }
        loaded = true
        await loadPlexLinks(client)
    }

    private func loadMore() async {
        guard let client = model.client, let next = cursor else { return }
        loadingMore = true
        defer { loadingMore = false }
        do {
            let page = try await client.requestsPage(view: "mine", filter: filter.rawValue, cursor: next, extra: sourceQuery)
            let known = Set(items.map(\.id))
            items += page.items.filter { !known.contains($0.id) }
            cursor = page.nextCursor
            await loadPlexLinks(client)
        } catch {
            model.toast(ErrorCopy.message(for: error), variant: .error)
        }
    }

    private func loadPlexLinks(_ client: APIClient) async {
        let ids = items.filter { $0.status == "fulfilled" && plexLinks[$0.id] == nil }.map(\.id)
        guard !ids.isEmpty, let links = try? await client.requestPlexLinks(ids: ids) else { return }
        plexLinks.merge(links) { _, new in new }
    }
}

/// "N of M requests left this week" with a pip per request, when the
/// requester has a limit (web `QuotaMeter`).
struct RequestQuotaMeter: View {
    let quota: RequestQuota

    var body: some View {
        if let limit = quota.limit, limit > 0 {
            let left = max(0, limit - quota.used)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    (Text("\(left)").fontWeight(.bold).foregroundColor(Theme.txt)
                     + Text(" of \(limit) requests left this week").foregroundColor(Theme.mut))
                        .font(.system(size: 14))
                    Spacer(minLength: 8)
                }
                HStack(spacing: 4) {
                    ForEach(0..<limit, id: \.self) { i in
                        Capsule()
                            .fill(i < quota.used ? (left == 0 ? Theme.miss : Theme.i1) : Theme.line)
                            .frame(height: 5)
                    }
                }
                Text(footnote)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.mut)
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }

    private var footnote: String {
        var parts: [String] = []
        if let day = RequestLifecycle.resetWeekday(quota.resetsAt) { parts.append("Resets \(day)") }
        parts.append("auto-requests count too")
        if quota.waiting > 0 { parts.append("\(quota.waiting) waiting") }
        return parts.joined(separator: " · ")
    }
}
