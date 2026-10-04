import SwiftUI
import FusionhaKit

/// The search tab: Discover rails before typing, OmniSearch lanes while typing.
/// First cut searches the library only; the "Add" lane and Discover rails follow the plan.
struct SearchView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var items: [LibraryItem] = []

    private var matches: [LibraryItem] {
        guard !query.isEmpty else { return [] }
        return items.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !matches.isEmpty {
                    Section("In your library") {
                        ForEach(matches) { item in
                            NavigationLink(value: item) {
                                HStack(spacing: 12) {
                                    PosterImage(url: TMDBImage.resized(item.posterUrl, to: "w92"))
                                        .frame(width: 32, height: 48)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.title).font(.subheadline.weight(.semibold))
                                        HStack(spacing: 4) {
                                            ForEach(item.editions) { EditionChip(tier: $0.tier, status: $0.status) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .navigationDestination(for: LibraryItem.self) { ItemDetailView(item: $0) }
            .searchable(text: $query, prompt: "Titles in your library")
            .overlay {
                if query.isEmpty {
                    ContentUnavailableView("Search and Discover", systemImage: "sparkles",
                                           description: Text("Trending and popular rails from Discover will live here."))
                } else if matches.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .task {
                if items.isEmpty, let client = model.client { items = (try? await client.library()) ?? [] }
            }
        }
    }
}
