import SwiftUI
import FusionhaKit

/// All titles' wanted shelves between the header and the grid (v2 mock
/// browse.js `homePhone`, minimize.js `homeScrolled`): "Missing episodes"
/// and "Upgrades waiting", each a sideways row of the library's posters from
/// `GET /api/v1/wanted?state=missing` / `cutoff_unmet`, its title count in
/// the header (`WantedShelf`). They follow the kind control; an empty one
/// hides, and both hide while searching or selecting. Cached answer first,
/// refreshed whenever the library reloads. A tap opens the title.
struct V2WantedShelves: View {
    let kind: String
    let gutter: CGFloat
    /// Searching or selecting: no rows (the loaded pages stay).
    var hidden = false
    @Environment(AppModel.self) private var model
    @State private var pages: [WantedShelf.Source: WantedPage] = [:]
    @State private var shelves: [WantedShelf] = []

    /// Enough of each feed that a kind's shelf rarely comes up short.
    static let pageSize = 200

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Always there, so the loading task runs with no shelf to show.
            Color.clear.frame(height: 0)
            if !hidden, !shelves.isEmpty {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(shelves) { shelf in
                        V2WantedShelfRow(shelf: shelf, gutter: gutter)
                    }
                }
                .padding(.top, 16)
            }
        }
        .task(id: model.libraryVersion) { await load() }
        .onChange(of: kind) { rebuild() }
    }

    private func load() async {
        guard !model.requestScoped, let client = model.client else { return }
        if pages.isEmpty {
            for source in WantedShelf.Source.allCases {
                let state = source.state
                if let kept = await client.cached({ try await $0.wantedPage(state: state, page: 1, pageSize: Self.pageSize) }) {
                    pages[source] = kept
                }
            }
        }
        rebuild()
        for source in WantedShelf.Source.allCases {
            let state = source.state
            guard let fresh = try? await client.wantedPage(state: state, page: 1, pageSize: Self.pageSize),
                  !Task.isCancelled else { continue }
            pages[source] = fresh
        }
        rebuild()
    }

    private func rebuild() {
        let only = LibraryKind(rawValue: kind)
        let next = WantedShelf.Source.allCases.compactMap {
            WantedShelf.make($0, page: pages[$0], library: model.library, kind: only)
        }
        if next != shelves { shelves = next }
    }
}
