import SwiftUI
import FusionhaKit

/// The viewer's own requests (web `MyRequestsList`): the quota meter, the
/// source note while a source is picked, the live request cards (newest
/// activity first, cursor-paged) and Load more. Show and Source come from the
/// filter sheet. Polls every 15 s while open and shows the last list from this
/// phone's cache straight away; reports its counts and result label to the nav.
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
            case .active: return "Nothing in flight right now."
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

    let show: Filter
    let source: RequestSourceFilter?
    @Environment(AppModel.self) private var model
    @Environment(DiscoverStore.self) private var store
    @Environment(RequestsNav.self) private var nav
    @State private var items: [MediaRequest] = []
    @State private var cursor: String?
    @State private var counts: RequestCounts?
    @State private var quota: RequestQuota?
    @State private var plexLinks: [Int: String] = [:]
    @State private var loaded = false
    @State private var failed = false
    @State private var loadingMore = false
    @State private var thread: MediaRequest?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let quota { RequestQuotaMeter(quota: quota) }
            if source != nil { RequestSourceNote() }
            content
        }
        .onChange(of: "\(show.count(counts) ?? -1)-\(items.count)-\(cursor != nil)", initial: true) {
            nav.resultLabel = RequestsResultLabel.text(show.count(counts), loaded: items.count, more: cursor != nil,
                                                       noun: ("request", "requests"))
        }
        .task(id: "\(show.rawValue)-\(store.requestsVersion)-\(sourceKey)") { await poll() }
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
            DiscoverEmptyState(message: source != nil ? "Nothing from this source matches this filter." : show.empty)
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
        if let page = await client.cached({ try await $0.requestsPage(view: "mine", filter: show.rawValue, extra: extra) }) {
            items = page.items
            cursor = page.nextCursor
            loaded = true
        }
        counts = await client.cached { try await $0.requestCounts(view: "mine", extra: extra) } ?? counts
        quota = await client.cached { try await $0.requestQuota() } ?? quota
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: .seconds(15))
        }
    }

    /// Re-reads the first page (keeping any pages already loaded beyond it),
    /// the counts (filtered for the button, unfiltered for the subtitle) and the quota.
    private func refresh() async {
        guard let client = model.client else { return }
        do {
            let extra = sourceQuery
            async let pageCall = client.requestsPage(view: "mine", filter: show.rawValue, extra: extra)
            async let countsCall = try? client.requestCounts(view: "mine", extra: extra)
            async let allCall = try? client.requestCounts(view: "mine")
            async let quotaCall = try? client.requestQuota()
            let page = try await pageCall
            let firstIds = Set(page.items.map(\.id))
            let beyond = items.dropFirst(page.items.count).filter { !firstIds.contains($0.id) }
            items = page.items + beyond
            if beyond.isEmpty { cursor = page.nextCursor }
            counts = await countsCall ?? counts
            if let all = await allCall { nav.mineCounts = all }
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
            let page = try await client.requestsPage(view: "mine", filter: show.rawValue, cursor: next, extra: sourceQuery)
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
