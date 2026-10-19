import SwiftUI
import FusionhaKit

// MARK: - Requester inline search

struct RequestorSearchResults: View {
    @Environment(AppModel.self) private var model
    @Environment(DiscoverStore.self) private var store
    let term: String
    let kind: SearchKind
    let canAdd: Bool
    let canRequest: Bool
    @State private var state: RailLoad<MediaSearchResult> = .loading

    var body: some View {
        Group {
            switch state {
            case .loading: line("Searching…")
            case .failed: line("Couldn't search right now — try again.")
            case .loaded(let items) where items.isEmpty: line("No results for “\(term)”.")
            case .loaded(let items):
                // Three tracks, 18 × 6 gaps, like every poster grid.
                AdaptivePosterGrid {
                    ForEach(items) { DiscoverCard(result: $0, canAdd: canAdd, canRequest: canRequest) }
                }
                .padding(.top, 4)
            }
        }
        .task(id: "\(term)|\(kind.rawValue)") {
            guard let client = model.client else { return }
            state = .loading
            do {
                state = .loaded(try await client.search(term: term, kind: kind))
            } catch is CancellationError {
            } catch {
                store.railFailed(error)
                state = .failed
            }
        }
    }

    private func line(_ text: String) -> some View {
        Text(text).font(.system(size: 13.5)).foregroundStyle(Theme.mut)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
