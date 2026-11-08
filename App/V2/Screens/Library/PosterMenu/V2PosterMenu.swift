import SwiftUI
import FusionhaKit

/// A Library poster's long press in v2 (Look Pass family 2, approved
/// behaviour change B1): the system context menu instead of v1's paged
/// sheet (`LibraryPosterSheet`). The same actions in the same order:
/// Automatic search, Interactive search ›, Monitor, Refresh metadata,
/// Edit…, Open in New Window, Delete…. Interactive search drills in as
/// submenus with the sheet's counts: a series picks a season (newest first,
/// Specials last, then Whole series), then the whole season (first) or one
/// episode, then the version; a movie picks the version. A single-version
/// title searches straight away, and it ends in the same scoped search.
struct V2PosterMenu: View {
    @Environment(AppModel.self) private var model
    let item: MediaItem

    private var monitored: Bool { item.monitored ?? true }
    private var isSeries: Bool { item.kind != .movie }
    private var detail: ItemDetail? { V2PosterMenuDetails.shared.detail(item.id) }

    var body: some View {
        Section {
            Button("Automatic search", systemImage: "magnifyingglass") { model.autoSearch(item.id) }
            interactive
        }
        Section {
            Toggle(isOn: Binding(get: { monitored }, set: { model.setMonitored(item.id, title: item.title, monitored: $0) })) {
                Label("Monitor", systemImage: monitored ? "bookmark.fill" : "bookmark")
            }
            Button("Refresh metadata", systemImage: "arrow.clockwise") { model.refreshMetadata(item.id, title: item.title) }
            Button("Edit…", systemImage: "pencil") { model.edit(item.id) }
            // v2 runs in several windows (split screen): this title in a window of its own.
            OpenInNewWindowButton(itemId: item.id)
        }
        Section {
            Button("Delete…", systemImage: "trash", role: .destructive) { model.confirmDelete(item.id, title: item.title) }
        }
    }

    // MARK: Interactive search

    @ViewBuilder
    private var interactive: some View {
        if let detail {
            if isSeries {
                Menu {
                    V2PosterSeasonsMenu(item: item, detail: detail, launch: launch)
                } label: {
                    Label("Interactive search", systemImage: "person")
                }
            } else {
                V2PosterVersionsMenu(item: item, detail: detail, target: .item, launch: launch) {
                    Label("Interactive search", systemImage: "person")
                }
            }
        } else {
            // The detail hasn't arrived: v1's per-version entry points, which
            // open the title's interactive search.
            if item.editions.count >= 2 {
                Menu {
                    ForEach(item.editions) { edition in
                        Button(edition.tier == .hd ? "HD 1080p" : "4K UHD") {
                            model.interactiveSearch(item.id, tier: edition.tier)
                        }
                    }
                } label: {
                    Label("Interactive search", systemImage: "person")
                }
            } else {
                Button("Interactive search", systemImage: "person") {
                    model.interactiveSearch(item.id, tier: item.editions.first?.tier)
                }
            }
        }
    }

    /// The poster sheet's launch: one version (or all of them, the
    /// recommended first) scoped to the target, on the title's search.
    private func launch(_ data: ItemDetail, _ target: SheetSearchTarget, _ versionId: Int, _ all: Bool) {
        guard let version = data.editions.first(where: { $0.id == versionId }) else { return }
        var ids = [versionId]
        if all { ids += data.editions.map(\.id).filter { $0 != versionId } }
        var episodeId: Int?, seasonNumber: Int?
        switch target {
        case .episode(_, let id, _): episodeId = id
        case .season(let season): seasonNumber = season
        case .item: break
        }
        let subtitle = all && target == .item ? "All versions" : PosterSheetModel.subtitle(target, version: version)
        model.scopedSearch(item.id, ScopedSearch(editionIds: ids, episodeId: episodeId,
                                                 seasonNumber: seasonNumber, subtitle: subtitle))
    }
}

/// What a poster submenu calls to start the search.
typealias V2PosterLaunch = (ItemDetail, SheetSearchTarget, Int, Bool) -> Void
