import SwiftUI
import FusionhaKit

/// A request's thread (web R2 `RequestThread`), as a sheet: the poster
/// header, then one scroll holding the status timeline and the conversation,
/// and the composer pinned under it. Polls new lines every 5 s with
/// `after_id` and moves the read marker when new lines arrive.
struct RequestThreadSheet: View {
    let onChanged: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
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
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        if canApprove && request.status == "pending" && !isOwner {
                            RequestApproverChips(request: request) {
                                Task { await refresh() }
                            }
                        }
                        sectionLabel("Timeline")
                        RequestStatusTimeline(request: request)
                        sectionLabel("Conversation")
                        RequestConversation(events: events, loaded: loaded, joinedView: joinedView)
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
            .background(Theme.bg)
            .navigationTitle("Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .task { await poll() }
        .onDisappear(perform: onChanged)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ActPoster(url: request.poster, title: title, size: .md)
            VStack(alignment: .leading, spacing: 6) {
                (Text(title).fontWeight(.bold) + Text(request.year.map { " (\($0))" } ?? "").foregroundColor(Theme.mut))
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.txt)
                HStack(spacing: 6) {
                    ForEach(request.tiers, id: \.self) { ActTierChip(tier: $0) }
                    if joinedView {
                        Text("Joined · \(request.demand?.count ?? 1) asked")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Theme.i2)
                    } else {
                        Text(RequestLifecycle.sourceText(request.source))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.mut)
                    }
                }
                if !joinedView, let demand = request.demand, demand.count > 1 {
                    Text("Also requested by \(demand.count - 1) \(demand.count == 2 ? "other" : "others")")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.mut)
                }
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

/// The message box: posts, then clears unless a newer draft was typed meanwhile.
struct RequestThreadComposer: View {
    let placeholder: String
    /// Posts one line (a request's or an issue's thread).
    let post: (APIClient, String) async throws -> RequestThreadEvent
    let onSent: (RequestThreadEvent) -> Void
    @Environment(AppModel.self) private var model
    @State private var text = ""
    @State private var sending = false

    var body: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...4)
                .font(.system(size: 15))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .onChange(of: text) { if text.count > 2000 { text = String(text.prefix(2000)) } }
                .submitLabel(.send)
                .onSubmit { Task { await send() } }
            Button { Task { await send() } } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.onPrimary)
                    .frame(width: 36, height: 36)
                    .background(Theme.fusion, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(sending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            .accessibilityLabel("Send")
            .padding(.trailing, 5)
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func send() async {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sending, !body.isEmpty, let client = model.client else { return }
        sending = true
        defer { sending = false }
        do {
            let line = try await post(client, body)
            if text.trimmingCharacters(in: .whitespacesAndNewlines) == body { text = "" }
            onSent(line)
        } catch {
            model.toast(ErrorCopy.message(for: error), title: "Could not send", variant: .error)
        }
    }
}
