import SwiftUI
import FusionhaKit

// MARK: - Search on the open iPhone Duo (S3)
//
// In a Spread the omni search's two lanes are poster grids: 6 across, 3 a side
// of the fold, while nothing is picked (the tab spans both pages), then the
// left page's columns with the picked title outlined. Same lanes, labels and
// words as the list; only the arrangement differs.

/// "In your library": the Library's poster cards (edition rails and all).
struct SearchOwnedGrid: View {
    let items: [MediaItem]

    var body: some View {
        AdaptivePosterGrid(spacing: 18, columnSpacing: 6) {
            ForEach(items) { PosterCard(item: $0) }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

/// "Available to add": Discover's cards; a tap opens the preview (on the
/// right page), the library title, or a requester's request modal.
struct SearchAddGrid: View {
    @Environment(AppModel.self) private var model
    let results: [MediaSearchResult]

    private var canAdd: Bool { model.me.map { $0.hasCapability("add") } ?? !model.requestScoped }
    private var canRequest: Bool { model.me?.hasCapability("request") ?? false }

    var body: some View {
        AdaptivePosterGrid {
            ForEach(results) { DiscoverCard(result: $0, canAdd: canAdd, canRequest: canRequest) }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
