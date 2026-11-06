import SwiftUI
import FusionhaKit

/// Press and hold on an episode row: the swipe actions plus Interactive
/// search, each v1's episode action for all versions.
struct V2EpisodeContextMenu: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    let seasonNumber: Int
    let episode: Episode

    private var canEdit: Bool { model.me?.can("edit") ?? true }
    private var canSearch: Bool { canEdit && (model.me?.can("search") ?? true) }
    private var code: String { EpisodeCode.episode(season: seasonNumber, episode: episode.episodeNumber) }

    var body: some View {
        if canSearch {
            let activity = store.activity(.episode(episode.id))
            // A menu item shows only text and a symbol: the row shows the spinner.
            Button(activity?.label ?? "Automatic search", systemImage: activity?.symbol ?? "magnifyingglass") {
                store.v2Search(.episode(episode.id), label: "\(detail.title) \(code)", episodeId: episode.id)
            }
            .disabled(activity?.isSearching == true)
            Button("Interactive search", systemImage: "person") {
                store.interactive = InteractiveTarget(editionIds: detail.orderedEditions.map(\.id), episodeId: episode.id,
                                                      subtitle: code)
            }
        }
        if canEdit {
            let on = store.episodeMonitored(episode)
            Button(on ? "Unmonitor" : "Monitor", systemImage: on ? "bookmark" : "bookmark.fill") {
                Task { await store.setEpisodeMonitored(episode, seasonNumber: seasonNumber, !on) }
            }
        }
    }
}
