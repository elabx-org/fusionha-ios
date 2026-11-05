import SwiftUI
import FusionhaKit

/// v2's Ground preview (plan S3): the art palette ground and the W1 cards
/// on it, from the owner's own library art, in any palette. Pick a title,
/// a palette and the page or list-pane recipe; below, three titles side by
/// side show that three posters give three distinct grounds.
struct GroundPreviewView: View {
    @Environment(AppModel.self) private var model
    @State private var pickId: Int?
    @State private var palette: AppPalette?
    @State private var recipe: PageGround.Recipe = .page

    /// Up to eight library titles with art.
    private var items: [MediaItem] {
        Array(model.library.lazy.filter { $0.backdropUrl != nil || $0.posterUrl != nil }.prefix(8))
    }

    private var picked: MediaItem? {
        guard let pickId else { return nil }
        return items.first { $0.id == pickId }
    }

    private var tokens: PaletteTokens { palette?.tokens ?? Theme.palette }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                controls
                GroundPreviewPage(item: picked, recipe: recipe)
                    .frame(height: 620)
                    .v2PageGround(art: picked.flatMap { PageArtSource.url(backdrop: $0.backdropUrl, poster: $0.posterUrl) },
                                  recipe: recipe, tokens: tokens)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .environment(\.colorScheme, tokens.isLight ? .light : .dark)
                trio
            }
            .padding(.horizontal, Theme.pageGutter)
            .padding(.vertical, 12)
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Recipe", selection: $recipe) {
                Text("Page").tag(PageGround.Recipe.page)
                Text("List pane").tag(PageGround.Recipe.listPane)
            }
            .pickerStyle(.segmented)
            HStack(spacing: 10) {
                Menu {
                    Button("No art (tint ground)") { pickId = nil }
                    ForEach(items) { item in
                        Button(item.title) { pickId = item.id }
                    }
                } label: {
                    Label(picked?.title ?? "No art", systemImage: "photo")
                        .lineLimit(1)
                }
                Menu {
                    Button("Active palette") { palette = nil }
                    ForEach(AppPalette.allCases) { p in
                        Button(p.name) { palette = p }
                    }
                } label: {
                    Label(palette?.name ?? "Active palette", systemImage: "paintpalette")
                        .lineLimit(1)
                }
            }
            .buttonStyle(.glass)
            Text(items.isEmpty
                 ? "The library has no art yet: only the tint ground can be shown."
                 : "The ground takes the art's three most vivid colours, lifted so they never go muddy; the cards are frosted material over it.")
                .font(.footnote)
                .foregroundStyle(Theme.mut)
        }
    }

    /// Three titles side by side: three distinct grounds.
    @ViewBuilder
    private var trio: some View {
        if items.count >= 3 {
            VStack(alignment: .leading, spacing: 9) {
                Text("Three titles, three grounds")
                    .font(.caption.weight(.heavy))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(Theme.dim)
                HStack(spacing: 10) {
                    ForEach(items.prefix(3)) { item in
                        GroundSwatch(title: item.title)
                            .frame(height: 220)
                            .v2PageGround(art: PageArtSource.url(backdrop: item.backdropUrl, poster: item.posterUrl),
                                          tokens: tokens)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .environment(\.colorScheme, tokens.isLight ? .light : .dark)
                    }
                }
            }
        }
    }
}

/// One small ground with a card on it.
private struct GroundSwatch: View {
    let title: String
    @Environment(\.pagePalette) private var page

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .foregroundStyle(page?.ink ?? Theme.txt)
                .frame(maxWidth: .infinity, alignment: .leading)
                .v2CardStyle(padding: 10, radius: 14)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
    }
}
