import SwiftUI
import FusionhaKit

enum DiscoverTab: Hashable {
    case browse, requests
}

/// The web's Discover page: kind filter, TMDB search, then Browse rails
/// (Trending, Popular, Upcoming, Top rated) or the Requests list.
struct DiscoverView: View {
    @Environment(AppModel.self) private var model
    @State private var kind: SearchKind = .movie
    @State private var tab: DiscoverTab = .browse
    @State private var query = ""
    @State private var results: [MediaSearchResult] = []
    @State private var searching = false
    @State private var trendingWindow = "week"

    var body: some View {
        Screen(showsAdd: true) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PageHeader(title: "Discover")
                    SegmentedPills(options: SearchKind.allCases.map { ($0, $0.title) }, selection: $kind, fill: true)
                    WebSearchField(placeholder: model.requestScoped ? "Search TMDB to request movies, series & anime…"
                                                                    : "Search TMDB to add movies, series & anime…",
                                   text: $query)
                    if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                        searchResults
                    } else {
                        if !model.requestScoped {
                            SegmentedPills(options: [(DiscoverTab.browse, "Browse"), (.requests, "Requests")],
                                           selection: $tab, style: .plain)
                        }
                        if tab == .browse || model.requestScoped {
                            DiscoverRail(title: "Trending", icon: "flame", tint: Theme.anime,
                                         kind: kind, list: .trending, window: trendingWindow) {
                                SegmentedPills(options: [("day", "Today"), ("week", "This Week")],
                                               selection: $trendingWindow)
                                    .scaleEffect(0.9, anchor: .leading)
                            }
                            DiscoverRail(title: "What's Popular", kind: kind, list: .popular)
                            DiscoverRail(title: "Upcoming", icon: "calendar", tint: Theme.cyan,
                                         kind: kind, list: kind == .movie ? .upcoming : .onTheAir)
                            DiscoverRail(title: "Top Rated", icon: "star", tint: Theme.onair, kind: kind, list: .topRated)
                        } else {
                            RequestsList()
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 14)
                .padding(.bottom, 90)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .task(id: "\(query)|\(kind.rawValue)") {
            let term = query.trimmingCharacters(in: .whitespaces)
            guard term.count >= 2 else { results = []; return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let client = model.client else { return }
            searching = true
            results = (try? await client.search(term: term, kind: kind)) ?? []
            searching = false
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        if searching && results.isEmpty {
            ProgressView().tint(Theme.mut).frame(maxWidth: .infinity).padding(.top, 30)
        } else if results.isEmpty {
            EmptyBox(message: "Nothing on TMDB matches “\(query)”.")
        } else {
            LazyVStack(spacing: 12) {
                ForEach(results) { SearchResultRow(result: $0) }
            }
        }
    }
}

/// A titled horizontal rail of TMDB posters.
private struct DiscoverRail<Accessory: View>: View {
    @Environment(AppModel.self) private var model
    let title: String
    var icon: String?
    var tint: Color = Theme.txt
    let kind: SearchKind
    let list: DiscoverList
    var window = "week"
    @ViewBuilder var accessory: Accessory
    @State private var items: [MediaSearchResult] = []
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(tint)
                }
                Text(title).font(.system(size: 20, weight: .heavy)).foregroundStyle(Theme.txt)
                Text("\(items.count) titles").font(.system(size: 13)).foregroundStyle(Theme.mut)
            }
            accessory
            if items.isEmpty {
                Text(loaded ? "No titles right now." : "Loading…")
                    .font(.system(size: 15)).foregroundStyle(Theme.mut)
                    .padding(.vertical, 18)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(items) { DiscoverCard(result: $0) }
                    }
                }
                .scrollClipDisabled()
            }
        }
        .padding(.top, 10)
        .task(id: "\(kind.rawValue)|\(list.rawValue)|\(window)") {
            guard let client = model.client else { return }
            items = (try? await client.discover(kind: kind, list: list, window: window)) ?? []
            loaded = true
        }
    }
}

extension DiscoverRail where Accessory == EmptyView {
    init(title: String, icon: String? = nil, tint: Color = Theme.txt, kind: SearchKind, list: DiscoverList) {
        self.init(title: title, icon: icon, tint: tint, kind: kind, list: list) { EmptyView() }
    }
}

/// A Discover poster: art with an in-library check, title and year.
private struct DiscoverCard: View {
    @Environment(AppModel.self) private var model
    let result: MediaSearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PosterImage(url: TMDBImage.resized(result.posterUrl, to: "w342"))
                .frame(width: 112, height: 168)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Theme.line))
                .overlay(alignment: .topTrailing) {
                    if result.inLibrary {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(Theme.done)
                            .frame(width: 22, height: 22)
                            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.done.opacity(0.55)))
                            .padding(8)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if let vote = result.voteAverage, vote > 0 {
                        Text(String(format: "%.1f", vote))
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 5))
                            .padding(8)
                    }
                }
            Text(result.title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
            HStack(spacing: 5) {
                if let year = result.year { Text(String(year)) }
                if result.isAnime { AnimeChip() }
            }
            .font(.system(size: 12)).foregroundStyle(Theme.mut)
        }
        .frame(width: 112)
        .contentShape(Rectangle())
        .onTapGesture {
            if result.inLibrary, let id = result.libraryItemId, !model.requestScoped {
                model.open(id)
            } else {
                model.addPrefill = result
                model.showingAdd = true
            }
        }
    }
}

/// Requests (all for approvers, the user's own for requesters).
struct RequestsList: View {
    @Environment(AppModel.self) private var model
    @State private var requests: [MediaRequest] = []
    @State private var previews: [Int: MediaPreview] = [:]
    @State private var loaded = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 10) {
            if requests.isEmpty {
                if !loaded {
                    ProgressView().tint(Theme.mut).frame(maxWidth: .infinity).padding(.top, 30)
                } else {
                    EmptyBox(message: error == nil ? "No requests yet." : "Requests could not be loaded.")
                }
            }
            ForEach(requests) { request in
                RequestRow(request: request, preview: previews[request.id])
                    .onTapGesture {
                        if let id = request.mediaItemId, !model.requestScoped { model.open(id) }
                    }
                    .task {
                        guard previews[request.id] == nil, let client = model.client else { return }
                        previews[request.id] = try? await client.preview(kind: request.kind, tmdbId: request.tmdbId)
                    }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            requests = try await client.requests()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loaded = true
    }
}

private struct RequestRow: View {
    let request: MediaRequest
    let preview: MediaPreview?

    private var statusColor: Color {
        switch request.status {
        case "approved": return Theme.grab
        case "fulfilled": return Theme.done
        case "rejected": return Theme.danger
        case "deferred": return Theme.unaired
        default: return Theme.miss
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            PosterImage(url: TMDBImage.resized(preview?.posterUrl, to: "w154"))
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(preview?.title ?? "TMDB #\(request.tmdbId)")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                HStack(spacing: 6) {
                    if let year = preview?.year { Text(String(year)) }
                    KindGlyph(kind: request.kind)
                    TierPill(tier: request.tier)
                }
                .font(.system(size: 12)).foregroundStyle(Theme.mut)
                if let requested = request.requestedAt {
                    Text("Requested \(Format.relative(requested))").font(.system(size: 11)).foregroundStyle(Theme.dim)
                }
            }
            Spacer(minLength: 0)
            Text(request.status == "fulfilled" ? "Available" : request.status.capitalized)
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundStyle(statusColor)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(statusColor.opacity(0.12), in: Capsule())
                .overlay(Capsule().strokeBorder(statusColor.opacity(0.45)))
        }
        .padding(12)
        .panel(Theme.card, radius: 14)
        .contentShape(Rectangle())
    }
}

/// Requester "My requests" tab.
struct RequestsView: View {
    var body: some View {
        Screen {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PageHeader(title: "My requests")
                    RequestsList()
                }
                .padding(.horizontal, 10)
                .padding(.top, 14)
                .padding(.bottom, 40)
            }
        }
    }
}

/// Requester "You" tab: the account page.
struct YouView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Screen {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PageHeader(title: "You")
                    HStack(spacing: 14) {
                        Avatar(me: model.me, size: 56)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.me?.username ?? "").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.txt)
                            Text(model.me?.roleLabel ?? "").font(.system(size: 14)).foregroundStyle(Theme.mut)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .panel(Theme.card, radius: 16)
                    if let server = model.credentials?.serverURL {
                        VStack(alignment: .leading, spacing: 4) {
                            EyebrowLabel(text: "Server")
                            Text(server.absoluteString).font(.system(size: 14, design: .monospaced)).foregroundStyle(Theme.txt)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .panel(Theme.card, radius: 16)
                        Link(destination: server) {
                            Label("Open web app", systemImage: "safari")
                                .font(.system(size: 15, weight: .bold))
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .panel(Theme.panel, radius: 12)
                        }
                        .foregroundStyle(Theme.txt)
                    }
                    Button(role: .destructive) { model.signOut() } label: {
                        Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 15, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .panel(Theme.panel, radius: 12)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.danger)
                }
                .padding(.horizontal, 10)
                .padding(.top, 14)
            }
        }
    }
}
