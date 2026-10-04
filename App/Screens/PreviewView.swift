import SwiftUI
import FusionhaKit

/// The Preview page for a title not in the library (`routes/PreviewDetail.tsx`,
/// mobile `PreviewFlyout`): a full-height sheet with the ambient art bleed, the
/// bottom-anchored hero, then overview, the add/request action, seasons,
/// trailer, "More like this" (pushes another preview) and cast.
struct PreviewSheet: View {
    let route: PreviewRoute
    /// Closes the sheet and opens the Add sheet with this title.
    let onAdd: (MediaSearchResult) -> Void
    /// Closes the sheet and opens the library item.
    let onOpenLibrary: (Int) -> Void

    var body: some View {
        NavigationStack {
            PreviewPage(route: route, onAdd: onAdd, onOpenLibrary: onOpenLibrary)
                .navigationDestination(for: PreviewRoute.self) { next in
                    PreviewPage(route: next, onAdd: onAdd, onOpenLibrary: onOpenLibrary)
                }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.bg)
        .presentationCornerRadius(14)
        .discoverToastOverlay(bottomInset: 24)
    }
}

struct PreviewPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let route: PreviewRoute
    let onAdd: (MediaSearchResult) -> Void
    let onOpenLibrary: (Int) -> Void

    @State private var detail: MediaPreviewDetail?
    @State private var failed = false
    @State private var compact = false
    @State private var requestPick: MediaSearchResult?
    @State private var playing = false
    @State private var entered = false

    private var me: Me? { model.me }
    private var canAdd: Bool { me.map { $0.hasCapability("add") } ?? !model.requestScoped }
    private var canRequest: Bool { me?.hasCapability("request") ?? false }

    var body: some View {
        ZStack(alignment: .top) {
            ambient
            if let detail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        hero(detail)
                        content(detail)
                    }
                    .opacity(entered || DiscoverMotion.reduced(reduceMotion) ? 1 : 0)
                    .offset(y: entered || DiscoverMotion.reduced(reduceMotion) ? 0 : 24)
                }
                .scrollIndicators(.hidden)
                .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y > 200 } action: { _, new in
                    withAnimation(DiscoverMotion.reduced(reduceMotion) ? nil : .easeOut(duration: 0.2)) { compact = new }
                }
                compactBar(detail)
            } else if failed {
                VStack(spacing: 14) {
                    (Text("That title could not be found on TMDB. Head back to ")
                        + Text("Discover").foregroundColor(Theme.cyan).fontWeight(.semibold) + Text("."))
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.mut)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .onTapGesture { dismiss() }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 80)
                .frame(maxWidth: .infinity)
            } else {
                PreviewSkeleton()
            }
        }
        .background(Theme.bg)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: route) { await load() }
        .sheet(item: $requestPick) { pick in
            RequestModal(pick: pick) {}
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            let loaded = try await client.discoverPreview(kind: route.kind, tmdbId: route.tmdbId)
            detail = loaded
            failed = false
            if DiscoverMotion.reduced(reduceMotion) {
                entered = true
            } else {
                withAnimation(DiscoverMotion.flyout()) { entered = true }
            }
        } catch is CancellationError {
        } catch {
            failed = true
        }
    }

    // MARK: Ambient bleed + compact bar

    @ViewBuilder
    private var ambient: some View {
        if let art = detail?.posterUrl ?? detail?.backdropUrl {
            GeometryReader { geo in
                DiscoverArt(url: TMDBImage.resized(art, to: "w342"))
                    .frame(width: geo.size.width * 1.28, height: geo.size.height * 1.28)
                    .offset(x: -geo.size.width * 0.14, y: -geo.size.height * 0.14)
                    .blur(radius: 72)
                    .saturation(1.4)
                    .brightness(-0.12)
                    .overlay {
                        LinearGradient(stops: [.init(color: Theme.bg.opacity(0.78), location: 0),
                                               .init(color: Theme.bg.opacity(0.62), location: 0.3),
                                               .init(color: Theme.bg.opacity(0.5), location: 1)],
                                       startPoint: .top, endPoint: .bottom)
                    }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func compactBar(_ detail: MediaPreviewDetail) -> some View {
        HStack(spacing: 10) {
            Text(detail.title)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(Theme.txt)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.mut)
                    .frame(width: 40, height: 40)
                    .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.line))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 12)
        .frame(height: 50)
        .background(Color(hex: 0x121419))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
        .opacity(compact ? 1 : 0)
        .offset(y: compact ? 0 : -8)
        .allowsHitTesting(compact)
        .accessibilityHidden(!compact)
    }

    // MARK: Hero

    private func hero(_ d: MediaPreviewDetail) -> some View {
        let art = d.posterUrl ?? d.backdropUrl
        return ZStack(alignment: .bottomLeading) {
            Group {
                if let art {
                    DiscoverArt(url: TMDBImage.resized(art, to: "w780"))
                        .mask {
                            LinearGradient(stops: [.init(color: .black, location: 0),
                                                   .init(color: .black, location: 0.4),
                                                   .init(color: .clear, location: 0.74)],
                                           startPoint: .top, endPoint: .bottom)
                        }
                } else {
                    RadialGradient(colors: [Color(hex: 0x1B1F2E), Theme.bg], center: .top, startRadius: 0, endRadius: 420)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            LinearGradient(stops: [.init(color: Theme.bg.opacity(0.14), location: 0),
                                   .init(color: .clear, location: 0.26),
                                   .init(color: Theme.bg.opacity(0.42), location: 0.62),
                                   .init(color: Theme.bg.opacity(0.3), location: 1)],
                           startPoint: .top, endPoint: .bottom)
            heroOverlay(d)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
        }
        .containerRelativeFrame(.vertical) { height, _ in min(max(height * 0.62, 430), 600) }
        .clipped()
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color(hex: 0x0C0D11).opacity(0.5), in: Circle())
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.line))
            }
            .buttonStyle(.plain)
            .padding(.leading, 12)
            .padding(.top, 8)
            .accessibilityLabel("Close")
        }
    }

    private func heroOverlay(_ d: MediaPreviewDetail) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let status = d.status, !status.isEmpty {
                StatusToneChip(status: status).padding(.bottom, 10)
            }
            (Text(d.title).font(.system(size: 33, weight: .black)).tracking(-0.66)
             + Text(verbatim: d.year.map { " \($0)" } ?? "").font(.system(size: 33, weight: .semibold)).foregroundColor(Theme.txt.opacity(0.78)))
                .foregroundStyle(Theme.txt)
                .lineSpacing(-2)
                .shadow(color: .black.opacity(0.6), radius: 10, y: 3)
            if let tagline = d.tagline, !tagline.isEmpty {
                Text(tagline).font(.system(size: 13)).italic().foregroundStyle(Theme.txt.opacity(0.86))
                    .padding(.top, 8)
            }
            metaLine(d).padding(.top, 12)
            if let genres = d.genres, !genres.isEmpty {
                PreviewFlow(spacing: 7) {
                    ForEach(genres, id: \.self) { genre in
                        Text(genre)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.txt.opacity(0.88))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Theme.panel.opacity(0.55), in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.line))
                    }
                }
                .padding(.top, 12)
            }
        }
    }

    private func metaLine(_ d: MediaPreviewDetail) -> some View {
        var items: [AnyView] = []
        let type = d.kind == .movie ? (d.isAnime ? "Anime Movie" : "Movie") : (d.isAnime ? "Anime" : "Series")
        items.append(AnyView(Text(type)))
        if let runtime = d.runtime, runtime > 0 { items.append(AnyView(Text("\(runtime) min"))) }
        if let vote = d.voteAverage, vote > 0 {
            items.append(AnyView(HStack(spacing: 4) {
                Image(systemName: "star.fill").font(.system(size: 12)).foregroundStyle(Color(hex: 0xF5C518))
                Text(String(format: "%.1f", vote))
            }))
        }
        if let cert = d.certification, !cert.isEmpty {
            items.append(AnyView(Text(cert)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.line))))
        }
        return HStack(spacing: 7) {
            ForEach(items.indices, id: \.self) { index in
                if index > 0 { Text("·").opacity(0.5) }
                items[index]
            }
        }
        .font(.system(size: 12.5))
        .foregroundStyle(Theme.txt.opacity(0.8))
    }

    // MARK: Body

    private func content(_ d: MediaPreviewDetail) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let overview = d.overview, !overview.isEmpty {
                Text(overview)
                    .font(.system(size: 14))
                    .lineSpacing(14 * 0.55 - 3)
                    .foregroundStyle(Theme.txt.opacity(0.9))
                    .shadow(color: .black.opacity(0.4), radius: 6)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }
            actions(d).padding(.top, 14)
            if d.kind == .series, let seasons = d.seasons, !seasons.isEmpty {
                section("Seasons") {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(seasons) { season in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(season.seasonNumber == 0 ? "Specials" : "Season \(season.seasonNumber)")
                                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                                Text(season.episodeCount == 1 ? "1 episode" : "\(season.episodeCount) episodes")
                                    .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .panel(Theme.panel2, radius: 12)
                        }
                    }
                }
            }
            if let key = d.trailerKey, !key.isEmpty {
                section("Trailer") { trailer(key) }
            }
            if let similar = d.similar, !similar.isEmpty {
                section("More like this") { similarRail(similar) }
            }
            if let cast = d.cast, !cast.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Text("CAST").font(.system(size: 12, weight: .bold)).tracking(0.72).foregroundStyle(Theme.mut)
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 16) {
                            ForEach(Array(cast.enumerated()), id: \.offset) { _, member in CastCard(member: member) }
                        }
                    }
                    .scrollClipDisabled()
                }
                .padding(.top, 26)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 24)
    }

    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt)
            content()
        }
        .padding(.top, 30)
    }

    @ViewBuilder
    private func actions(_ d: MediaPreviewDetail) -> some View {
        if d.inLibrary {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    PosterStatusBadge(kind: .inLibrary)
                    Text("Already in your library").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                }
                if let id = d.libraryItemId {
                    Button("Open in library") { onOpenLibrary(id) }
                        .buttonStyle(.discover(.primary))
                }
            }
        } else if canAdd {
            // The add options live in the Add sheet on iOS; it opens with this
            // title picked, on its configure step.
            Button { onAdd(d.asSearchResult) } label: {
                Label("Add to library", systemImage: "plus")
            }
            .buttonStyle(.discover(.primary))
        } else if canRequest {
            Button("Request") { requestPick = d.asSearchResult }
                .buttonStyle(.discover(.primary))
        }
    }

    @ViewBuilder
    private func trailer(_ key: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                if playing, let url = URL(string: "https://www.youtube-nocookie.com/embed/\(key)?autoplay=1&rel=0&playsinline=1") {
                    YouTubePlayer(url: url)
                } else {
                    Button { playing = true } label: {
                        Color.clear
                            .overlay { DiscoverArt(url: URL(string: "https://i.ytimg.com/vi/\(key)/hqdefault.jpg")) }
                            .overlay {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white)
                                    .frame(width: 66, height: 66)
                                    .background(Color(red: 15 / 255, green: 15 / 255, blue: 20 / 255).opacity(0.62), in: Circle())
                                    .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 2))
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(DiscoverPressStyle())
                    .accessibilityLabel("Play trailer")
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .frame(maxWidth: 640)
            .background(Theme.panel2)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
            if let url = URL(string: "https://www.youtube.com/watch?v=\(key)") {
                Link("Watch on YouTube", destination: url)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.cyan)
            }
        }
    }

    private func similarRail(_ cards: [SimilarCard]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 16) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    NavigationLink(value: PreviewRoute(kind: card.kind == .movie ? .movie : .series, tmdbId: card.tmdbId)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Color.clear
                                .aspectRatio(2 / 3, contentMode: .fit)
                                .overlay { DiscoverArt(url: TMDBImage.resized(card.posterUrl, to: "w342")) }
                                .background(Theme.panel2)
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Theme.line))
                                .shadow(color: .black.opacity(0.55), radius: 12, y: 12)
                                .overlay(alignment: .topTrailing) {
                                    if card.inLibrary { PosterStatusBadge(kind: .inLibrary).padding(8) }
                                }
                                .padding(.bottom, 6)
                            Text(card.title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                            if let year = card.year {
                                Text(verbatim: "\(year)").font(.system(size: 11.5)).foregroundStyle(Theme.mut)
                            }
                        }
                    }
                    .buttonStyle(DiscoverPressStyle())
                    .containerRelativeFrame(.horizontal) { width, _ in (width - 32) / 3 }
                    .discoverReveal(index: index)
                }
            }
        }
        .scrollClipDisabled()
    }
}

/// The hero status chip: clock icon + mono uppercase status, toned by meaning.
private struct StatusToneChip: View {
    let status: String

    private var tone: (bg: Color, fg: Color, border: Color) {
        let s = status.lowercased()
        if ["released", "available", "ended"].contains(where: { s.contains($0) }) {
            return (Color(hex: 0x143C32), Color(hex: 0x7CDCBC), Color(hex: 0x7CDCBC).opacity(0.3))
        }
        if ["continuing", "returning", "airing", "on air", "production", "planned", "upcoming"].contains(where: { s.contains($0) }) {
            return (Color(hex: 0x443716), Color(hex: 0xF4D076), Color(hex: 0xF4D076).opacity(0.3))
        }
        return (Color(hex: 0x2A2D34), Theme.mut, Theme.line)
    }

    var body: some View {
        let t = tone
        HStack(spacing: 5) {
            Image(systemName: "clock").font(.system(size: 11, weight: .semibold))
            Text(status.uppercased()).font(.system(size: 10, weight: .heavy, design: .monospaced)).tracking(0.4)
        }
        .foregroundStyle(t.fg)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(t.bg, in: Capsule())
        .overlay(Capsule().strokeBorder(t.border))
    }
}

private struct CastCard: View {
    let member: CastMember

    private var initials: String {
        let parts = member.name.split(separator: " ")
        let letters = parts.count >= 2 ? [parts[0].first, parts[1].first].compactMap { $0 } : Array(member.name.prefix(2))
        return String(letters).uppercased()
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                LinearGradient(colors: [Theme.indigo, Theme.cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(initials).font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                if let url = member.profileUrl.flatMap({ TMDBImage.resized($0, to: "w185") }) {
                    DiscoverArt(url: url)
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            Text(member.name).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt)
                .multilineTextAlignment(.center).lineLimit(2)
            if let character = member.character, !character.isEmpty {
                Text(character).font(.system(size: 12)).foregroundStyle(Theme.mut)
                    .multilineTextAlignment(.center).lineLimit(2)
            }
        }
        .frame(width: 96)
    }
}

private struct PreviewSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DiscoverShimmer(radius: 0).frame(height: 430)
            DiscoverShimmer().frame(width: 220, height: 26).padding(.horizontal, 16)
            DiscoverShimmer().frame(width: 160, height: 12).padding(.horizontal, 16)
            DiscoverShimmer().frame(height: 60).padding(.horizontal, 16)
            Spacer()
        }
    }
}

/// A wrapping row (genre chips).
struct PreviewFlow: Layout {
    var spacing: CGFloat = 7

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(maxX, width), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
