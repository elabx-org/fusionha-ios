import SwiftUI
import FusionhaKit

/// Item detail, first cut: hero, editions panel and search. Seasons, Files, History,
/// interactive search and the edit dialogs follow the plan's screen mapping.
struct ItemDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    let item: MediaItem
    @State private var searching = false
    @State private var searchSent = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                VStack(alignment: .leading, spacing: 12) {
                    Text("Editions").font(.headline)
                    ForEach(item.editions) { EditionCard(edition: $0) }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 32)
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await search() }
                } label: {
                    Image(systemName: searchSent ? "checkmark" : "magnifyingglass")
                        .contentTransition(.symbolEffect(.replace))
                }
                .disabled(searching)
                .accessibilityLabel("Automatic search")
                .sensoryFeedback(.success, trigger: searchSent)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let server = model.credentials?.serverURL {
                        Button("Open in web app", systemImage: "safari") {
                            openURL(server.appendingPathComponent("library/\(item.id)"))
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            PosterImage(url: TMDBImage.resized(item.backdropUrl ?? item.posterUrl, to: "w1280"))
                .frame(height: 300)
                .clipped()
                .backgroundExtensionEffect()
                .overlay(LinearGradient(colors: [.clear, Color(.systemBackground)], startPoint: .center, endPoint: .bottom))
            HStack(alignment: .bottom, spacing: 14) {
                PosterImage(url: TMDBImage.resized(item.posterUrl, to: "w342"))
                    .frame(width: 96, height: 144)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: 10, y: 4)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.title2.bold()).lineLimit(2)
                    HStack(spacing: 6) {
                        if let year = item.year { Text(String(year)) }
                        Text(item.isAnime == true ? "Anime" : (item.kind == .movie ? "Movie" : "Series"))
                            .foregroundStyle(item.isAnime == true ? Theme.anime : .secondary)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
        }
    }

    private func search() async {
        searching = true
        defer { searching = false }
        do {
            try await model.client?.searchItem(id: item.id)
            searchSent = true
            try? await Task.sleep(for: .seconds(2))
            searchSent = false
        } catch {}
    }
}

/// Edition card with the status-coloured top hairline (never a left rail).
struct EditionCard: View {
    let edition: Edition

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                EditionChip(tier: edition.tier)
                if let cut = edition.movieEdition {
                    Text(cut).font(.caption.weight(.medium)).foregroundStyle(Theme.edition)
                }
                Spacer()
                Image(systemName: edition.monitored ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(edition.monitored ? Theme.indigo : .secondary)
                    .accessibilityLabel(edition.monitored ? "Monitored" : "Not monitored")
            }
            HStack {
                Circle().fill(edition.status.color).frame(width: 8, height: 8)
                Text(edition.status.label).font(.subheadline)
                Spacer()
                if let have = edition.have, let total = edition.total, total > 0 {
                    Text("\(have)/\(total)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12)
                .fill(edition.status.color)
                .frame(height: 2)
        }
    }
}
