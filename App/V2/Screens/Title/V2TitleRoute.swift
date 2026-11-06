import SwiftUI
import FusionhaKit

/// The pages pushed over a v2 title (slice S6): a season, then an episode.
/// Both hosts (`RootView`'s sheet and `DuoLayout`'s column) wrap the title
/// in a `NavigationStack`, so these push inside it.
enum V2TitleRoute: Hashable {
    case season(Int)
    case episode(season: Int, episodeId: Int)
}

/// A pushed page with the title's store and motion setting. They are
/// passed again here because a pushed destination is not a child of the
/// view that set them.
struct V2TitleDestination: View {
    let route: V2TitleRoute
    let store: DetailStore
    let reduceMotion: Bool
    /// Tells the stack this page is on top or gone (`DuoPageAtRoot`).
    var visible: (Bool) -> Void = { _ in }

    @Environment(\.duoOpen) private var duoOpen
    @Environment(\.bookPose) private var bookPose
    @Environment(\.duoListToggle) private var listToggle

    var body: some View {
        Group {
            if V2TitleWide.fills(duoOpen: duoOpen, bookPose: bookPose, toggle: listToggle) {
                // The title fills the flat open Duo: band, siblings | page (S7).
                V2TitleWideChild(route: route)
            } else {
                switch route {
                case .season(let number):
                    V2SeasonPage(seasonNumber: number)
                case .episode(let season, let episodeId):
                    V2EpisodePage(seasonNumber: season, episodeId: episodeId)
                }
            }
        }
        .environment(store)
        .environment(\.detailReduceMotion, reduceMotion)
        .v2TitleLiveImport(store)
        .onAppear { visible(true) }
        .onDisappear { visible(false) }
    }
}

extension View {
    /// Registers the title's pushed pages, and turns v1's episode sheet
    /// (`store.episodeSheet`, set by Next up, the Files tab's gaps and deep
    /// links) into a pushed episode page.
    func v2TitleDestinations(store: DetailStore, reduceMotion: Bool) -> some View {
        modifier(V2TitleDestinations(store: store, reduceMotion: reduceMotion))
    }
}

private struct V2TitleDestinations: ViewModifier {
    let store: DetailStore
    let reduceMotion: Bool
    @State private var pushed: V2TitleRoute?
    /// The pushed pages on screen. Empty means the title itself is on top,
    /// so the open Duo's leading-edge swipe (`DuoPageEdge`) may close the
    /// page; otherwise the edge is the system Back.
    @State private var visible: Set<V2TitleRoute> = []

    func body(content: Content) -> some View {
        content
            .preference(key: DuoPageAtRoot.self, value: visible.isEmpty)
            .navigationDestination(for: V2TitleRoute.self) { route in
                destination(route)
            }
            .navigationDestination(item: $pushed) { route in
                destination(route)
            }
            .onChange(of: store.episodeSheet?.id, initial: true) {
                guard let target = store.episodeSheet else { return }
                store.episodeSheet = nil
                pushed = .episode(season: target.seasonNumber, episodeId: target.episodeId)
            }
    }

    private func destination(_ route: V2TitleRoute) -> some View {
        V2TitleDestination(route: route, store: store, reduceMotion: reduceMotion) { shown in
            if shown { visible.insert(route) } else { visible.remove(route) }
        }
    }
}
