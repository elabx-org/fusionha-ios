import SwiftUI
import FusionhaKit

enum EpisodeSheetTab: String, CaseIterable {
    case details, history, search
    var title: String { rawValue.capitalized }
}

/// Which episode the sheet shows, and the tab it opens on (a row tap lands on
/// Details; the row's interactive-search button on Search).
struct EpisodeSheetTarget: Identifiable {
    let id = UUID()
    let episodeId: Int
    let seasonNumber: Int
    var tab: EpisodeSheetTab = .details
}

/// The episode dialog as a sheet (EpisodeDetailDialog.tsx, ruling L8):
/// Details (overview, monitored, runtime, per-version status and each owned
/// file), History (this episode's events) and Search (interactive search for
/// this one episode), with Auto search in the footer.
struct EpisodeDetailSheet: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.detailReduceMotion) private var reduce
    let target: EpisodeSheetTarget
    @State private var tab: EpisodeSheetTab = .details
    @State private var search: InteractiveSearchModel?

    private var detail: ItemDetail? { store.detail }
    private var episode: Episode? {
        detail?.seasons?.first { $0.seasonNumber == target.seasonNumber }?.episodes.first { $0.id == target.episodeId }
    }
    private var code: String {
        EpisodeCode.episode(season: target.seasonNumber, episode: episode?.episodeNumber ?? 0, separator: "")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let detail, let episode {
                    heading(detail, episode)
                    Picker("Episode detail", selection: $tab) {
                        ForEach(EpisodeSheetTab.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                    pane(detail, episode)
                        .id(tab)
                        .transition(.opacity)
                } else {
                    EmptyBox(message: "This episode is no longer in the library.").padding(16)
                    Spacer()
                }
            }
            .detailAnimation(.easeInOut(duration: 0.18), value: tab)
            .background(Theme.panel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton(title: "Close") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) { footer }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.panel)
        .onAppear(perform: restore)
        .onDisappear(perform: park)
        .onChange(of: tab, initial: true) { _, new in
            if new == .search && search == nil, let detail, let episode { search = makeSearch(detail, episode) }
        }
    }

    // MARK: Fold / unfold (DC3)

    /// A fold / unfold re-hosts this sheet: park the open tab and the Search
    /// tab's model under the episode target, and pick them up on the new host.
    /// `opened("episode")` clears them when a different episode opens.
    private func park() {
        store.drafts.save(target.id, for: "episode.target")
        store.drafts.save(tab, for: "episode.tab")
        if let search { store.drafts.save(search, for: "episode.search") }
    }

    private func restore() {
        guard store.drafts.value("episode.target", as: UUID.self) == target.id else {
            tab = target.tab
            return
        }
        search = store.drafts.value("episode.search", as: InteractiveSearchModel.self)
        tab = store.drafts.value("episode.tab", as: EpisodeSheetTab.self) ?? target.tab
    }

    private func heading(_ detail: ItemDetail, _ episode: Episode) -> some View {
        var sub: [String] = []
        if let instant = episode.airInstant {
            sub.append("\(episode.hasAired() ? "Aired" : "Airs") \(instant.formatted(date: .abbreviated, time: .omitted))")
        }
        return DialogHeading(symbol: "tv", title: "\(detail.title) — \(code) · \(episode.title ?? "Episode \(episode.episodeNumber)")",
                             subtitle: sub.joined(separator: " · "))
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
    }

    @ViewBuilder
    private func pane(_ detail: ItemDetail, _ episode: Episode) -> some View {
        switch tab {
        case .details:
            ScrollView {
                EpisodeDetailsPane(detail: detail, episode: episode, seasonNumber: target.seasonNumber)
                    .padding(16)
            }
        case .history:
            ScrollView {
                EpisodeHistoryPane(detail: detail, episode: episode, seasonNumber: target.seasonNumber)
                    .padding(16)
            }
        case .search:
            if let search { InteractiveSearchPane(model: search) } else { Spacer() }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if tab != .search, episode != nil, model.me?.can("search") ?? true {
            HStack {
                Spacer()
                SearchActionButton(label: "\(detail?.title ?? "") — \(code)", editionId: store.scopeEditionId,
                                   episodeId: target.episodeId, accessibility: "Auto search \(code)",
                                   title: "Auto search")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    /// The Search tab's version: the first scoped version missing this episode, else the first.
    private func makeSearch(_ detail: ItemDetail, _ episode: Episode) -> InteractiveSearchModel {
        let shown = store.scopedEditions
        let version = shown.first { episode.file(for: $0.id) == nil } ?? shown.first
        let ids = version.map { [$0.id] } ?? []
        return InteractiveSearchModel(store: store, target: InteractiveTarget(
            editionIds: ids, episodeId: episode.id, subtitle: "S\(target.seasonNumber)·E\(episode.episodeNumber)"))
    }
}

/// The History tab: the timeline rows of this episode's events.
private struct EpisodeHistoryPane: View {
    @Environment(DetailStore.self) private var store
    let detail: ItemDetail
    let episode: Episode
    let seasonNumber: Int

    var body: some View {
        let ids = detail.scopeEditionIds(store.scope)
        let rows = EpisodeHistory.rows(detail.history ?? [], episodeId: episode.id, seasonNumber: seasonNumber, versionIds: ids)
        if rows.isEmpty {
            EmptyBox(message: "No history yet for this episode.")
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(rows) { TimelineRow(detail: detail, entry: $0) }
            }
        }
    }
}
