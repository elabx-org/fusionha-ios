import SwiftUI
import FusionhaKit

/// The managers' threads (web A7 `ThreadsPanel`, phone layout): request and
/// issue threads in one list by last activity, filtered by kind (when the
/// viewer can manage both) and Open · Resolved · All; a row opens its thread.
struct ThreadsPanelView: View {
    /// Fix the list to one kind (e.g. Discover's Issues tab).
    var only: String? = nil
    /// Set by a parent that shows the state in its own filter sheet
    /// (Requests › Issues): open · resolved · all; hides the picker here.
    var state: String? = nil
    /// The loaded rows, for the parent's count.
    var onItems: (([ThreadItem]) -> Void)? = nil
    @Environment(AppModel.self) private var model
    @State private var kind = "all"
    @State private var mode = "open"
    @State private var items: [ThreadItem] = []
    @State private var cursor: String?
    @State private var loaded = false
    @State private var failed = false
    @State private var open: ThreadItem?

    private var canRequests: Bool { model.me?.hasPermission("requests.approve") ?? false }
    private var canIssues: Bool { model.me?.hasPermission("issues.manage") ?? false }
    private var fixed: String? { only ?? (canRequests && !canIssues ? "request" : (canIssues && !canRequests ? "issue" : nil)) }
    private var effective: String? { fixed ?? (kind == "all" ? nil : kind) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if fixed == nil {
                Picker("Thread type", selection: $kind) {
                    Text(countLabel("All", nil)).tag("all")
                    Text(countLabel("Requests", "request")).tag("request")
                    Text(countLabel("Issues", "issue")).tag("issue")
                }
                .pickerStyle(.segmented)
            }
            if state == nil {
                Picker("Thread state", selection: $mode) {
                    Text("Open").tag("open")
                    Text("Resolved").tag("resolved")
                    Text("All").tag("all")
                }
                .pickerStyle(.segmented)
            }
            content
        }
        .onChange(of: items) { onItems?(items) }
        .task(id: "\(effective ?? "all")-\(currentMode)") {
            items = []
            cursor = nil
            loaded = false
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(for: .seconds(15))
            }
        }
        .sheet(item: $open) { item in
            if item.type == "issue", let issue = item.issue {
                IssuePaneSheet(seed: issue, linkedRequestId: item.linkedPendingRequestId)
            } else if let request = item.request {
                RequestThreadSheet(request: request) { Task { await load() } }
            }
        }
    }

    /// Totals only while the list is unfiltered and fully loaded.
    private func countLabel(_ label: String, _ type: String?) -> String {
        guard effective == nil, cursor == nil, loaded else { return label }
        let n = type.map { t in items.filter { $0.type == t }.count } ?? items.count
        return "\(label) \(n)"
    }

    @ViewBuilder
    private var content: some View {
        if !loaded {
            DiscoverEmptyState(message: "Loading threads…")
        } else if failed && items.isEmpty {
            DiscoverEmptyState(message: "Could not load threads.")
        } else if items.isEmpty {
            DiscoverEmptyState(message: "Nothing here. Switch the filter to see the rest.")
        } else {
            LazyVStack(spacing: 8) {
                ForEach(items) { item in
                    Button { open = item } label: { ThreadRowView(item: item) }.buttonStyle(.plain)
                }
                if cursor != nil {
                    Button("Load more") { Task { await loadMore() } }.buttonStyle(.discover(.subtle))
                }
            }
        }
    }

    private var currentMode: String { state ?? mode }
    private var stateParam: String? { currentMode == "open" ? "OPEN" : (currentMode == "resolved" ? "RESOLVED" : nil) }

    private func load() async {
        guard let client = model.client else { return }
        do {
            let page = try await client.adminThreads(type: effective, state: stateParam)
            let firstIds = Set(page.items.map(\.id))
            let beyond = items.dropFirst(page.items.count).filter { !firstIds.contains($0.id) }
            items = page.items + beyond
            if beyond.isEmpty { cursor = page.nextCursor }
            failed = false
        } catch is CancellationError {
            return
        } catch {
            failed = true
        }
        loaded = true
    }

    private func loadMore() async {
        guard let client = model.client, let cursor,
              let page = try? await client.adminThreads(type: effective, state: stateParam, cursor: cursor) else { return }
        let known = Set(items.map(\.id))
        items += page.items.filter { !known.contains($0.id) }
        self.cursor = page.nextCursor
    }
}

/// One thread: kind, poster, title, the problem or "Request" with tiers, who
/// (and who it's waiting on), the state and last activity with an unread dot.
struct ThreadRowView: View {
    let item: ThreadItem

    var body: some View {
        let title = ThreadMeta.title(item)
        let people = ThreadMeta.people(item)
        let issue = item.type == "issue" ? item.issue : nil
        HStack(alignment: .top, spacing: 10) {
            ActPoster(url: item.poster ?? issue?.poster ?? item.request?.poster, title: title, size: .sm)
            VStack(alignment: .leading, spacing: 4) {
                (Text(title).fontWeight(.semibold) + Text((item.year ?? issue?.mediaYear ?? item.request?.year).map { " (\($0))" } ?? "").foregroundColor(Theme.mut))
                    .font(.system(size: 14.5)).foregroundStyle(Theme.txt).lineLimit(1)
                HStack(spacing: 5) {
                    Image(systemName: issue != nil ? "flag" : "film").font(.system(size: 11))
                    Text(ThreadMeta.lineLabel(item))
                    ForEach(ThreadMeta.tiers(item), id: \.self) { ActTierChip(tier: $0) }
                }
                .font(.system(size: 12)).foregroundStyle(Theme.mut)
                if let first = people.first {
                    (Text(first.name + (people.count > 1 ? " +\(people.count - 1)" : "")).fontWeight(.semibold)
                     + Text(ThreadMeta.waitingOn(item).map { " · waiting on \($0)" } ?? "").foregroundColor(Theme.mut))
                        .font(.system(size: 12)).foregroundStyle(Theme.txt).lineLimit(1)
                }
                if let message = item.lastMessage {
                    Text(message.line).font(.system(size: 12.5)).foregroundStyle(Theme.mut).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 6) {
                if let issue {
                    IssueStateChip(state: issue.state ?? "OPEN", reopenCount: issue.reopenCount ?? 0)
                } else {
                    Text(ThreadMeta.stateLabel(item)).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.mut)
                }
                HStack(spacing: 4) {
                    if ThreadMeta.hasUnread(item) { Circle().fill(Theme.primary).frame(width: 8, height: 8).accessibilityLabel("Unread") }
                    Text(ActFmt.relative(item.lastEventAt)).font(.system(size: 11.5)).foregroundStyle(Theme.dim)
                }
            }
        }
        .padding(10)
        .actWash(washColor, radius: 14, base: Theme.card)
        .accessibilityElement(children: .combine)
    }

    private var washColor: Color {
        if item.type == "request", let r = item.request {
            return RequestLifecycle.wash(status: r.status, lifecycle: r.lifecycle ?? []).color
        }
        switch item.issue?.state {
        case "RESOLVED": return Theme.done
        case "CHECKING", "FIXING": return Theme.grab
        default: return Theme.stuck
        }
    }
}
