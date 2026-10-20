import SwiftUI
import FusionhaKit

/// A request's thread (web R2 `RequestThread`): the poster header, then one
/// scroll holding the status timeline and the conversation, and the composer
/// pinned under it. Polls new lines every 5 s with `after_id` and moves the
/// read marker when new lines arrive. The phone shows it in a sheet
/// (`RequestThreadSheet`); wide, it is the web's right-hand panel
/// (`RequestThreadPane`) or the Threads split's pane (DU5).
struct RequestThreadView: View {
    let onChanged: () -> Void
    @Environment(AppModel.self) private var model
    @State private var request: MediaRequest
    @State private var events: [RequestThreadEvent] = []
    @State private var loaded = false
    @State private var marked = 0

    init(request: MediaRequest, onChanged: @escaping () -> Void) {
        _request = State(initialValue: request)
        self.onChanged = onChanged
    }

    private var title: String {
        request.title ?? PreviewCache.shared.get(request.previewKind, request.tmdbId)?.title ?? "Request"
    }
    private var isOwner: Bool { request.userId != nil && request.userId == model.me?.id }
    private var joinedView: Bool { RequestLifecycle.isJoinedView(request, viewerId: model.me?.id) }
    private var canApprove: Bool { model.me?.hasPermission("requests.approve") ?? false }
    private var canPost: Bool { isOwner || joinedView || canApprove }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if canApprove && request.status == "pending"
                        && !OwnRequestRule.locked(request, viewerId: model.me?.id, viewerIsAdmin: model.me?.isAdmin == true) {
                        RequestApproverChips(request: request) {
                            Task { await refresh() }
                        }
                    }
                    sectionLabel("Timeline")
                    RequestStatusTimeline(request: request)
                    sectionLabel("Conversation")
                    RequestConversation(events: events, loaded: loaded, joinedView: joinedView, source: request.source)
                    Color.clear.frame(height: 1).id("end")
                }
                .padding(16)
            }
            .onChange(of: events.count) { proxy.scrollTo("end", anchor: .bottom) }
        }
        .safeAreaInset(edge: .bottom) {
            if canPost {
                RequestThreadComposer(placeholder: RequestThreadFormat.placeholder(request, isOwner: isOwner, joinedView: joinedView),
                                      post: { [id = request.id] client, body in try await client.postRequestMessage(id: id, body: body) }) { line in append([line]) }
            }
        }
        .task { await poll() }
        .onDisappear(perform: onChanged)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ActPoster(url: request.poster, title: title, size: .md)
            VStack(alignment: .leading, spacing: 6) {
                (Text(title).fontWeight(.bold) + Text(verbatim: request.year.map { " (\($0))" } ?? "").foregroundColor(Theme.mut))
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.txt)
                HStack(spacing: 6) {
                    ForEach(request.tiers, id: \.self) { ActTierChip(tier: $0) }
                    if joinedView {
                        RequestJoinedPill(request: request)
                    } else {
                        RequestSourceBadge(source: request.source, mine: isOwner)
                    }
                }
                if !joinedView { RequestDemandLine(demand: request.demand) }
            }
            Spacer(minLength: 0)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(Theme.dim)
    }

    // MARK: Polling

    private func poll() async {
        guard let client = model.client else { return }
        while !Task.isCancelled {
            if let fresh = try? await client.requestEvents(id: request.id, afterId: events.last?.id ?? 0) {
                append(fresh)
            }
            loaded = true
            if let detail = try? await client.requestDetail(id: request.id) { request = detail }
            await markRead(client)
            try? await Task.sleep(for: .seconds(5))
        }
    }

    private func refresh() async {
        guard let client = model.client else { return }
        if let detail = try? await client.requestDetail(id: request.id) { request = detail }
        if let fresh = try? await client.requestEvents(id: request.id, afterId: events.last?.id ?? 0) { append(fresh) }
        onChanged()
    }

    private func append(_ lines: [RequestThreadEvent]) {
        let known = Set(events.map(\.id))
        let fresh = lines.filter { !known.contains($0.id) }
        guard !fresh.isEmpty else { return }
        events = (events + fresh).sorted { $0.id < $1.id }
    }

    private func markRead(_ client: APIClient) async {
        guard model.me != nil, let last = events.last?.id, last > marked else { return }
        marked = last
        try? await client.markRequestRead(id: request.id, lastEventId: last)
    }
}
