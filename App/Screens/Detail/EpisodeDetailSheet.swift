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

/// The episode dialog (EpisodeDetailDialog.tsx, ruling L8): Details
/// (overview, Monitored, each version's status and owned file), History (this
/// episode's events) and Search (interactive search for this one episode).
/// The heading is the episode's own title with the air date and runtime;
/// Auto search is in the bar.
///
/// A sheet folded, on a phone and in the Web layout; on the open Duo in a
/// Spread it is the right page beside its title (`inline`, `DetailSpreadBody`):
/// no stack, grabber or sheet ground, the code and Auto search in the page's
/// own bar, and the title column's Close closes it.
struct EpisodeDetailSheet: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.detailReduceMotion) private var reduce
    let target: EpisodeSheetTarget
    var inline = false
    @State private var tab: EpisodeSheetTab = .details
    @State private var search: InteractiveSearchModel?

    private var detail: ItemDetail? { store.detail }
    private var episode: Episode? {
        detail?.seasons?.first { $0.seasonNumber == target.seasonNumber }?.episodes.first { $0.id == target.episodeId }
    }
    private var code: String {
        EpisodeCode.episode(season: target.seasonNumber, episode: episode?.episodeNumber ?? 0, separator: "")
    }
    /// 20 pt from a page's edges, the sheet's usual 16.
    private var gutter: CGFloat { inline ? 20 : 16 }
    private var canSearch: Bool { episode != nil && (model.me?.can("search") ?? true) }
    private var searchLabel: String { "\(detail?.title ?? "") — \(code)" }

    var body: some View {
        Group {
            if inline { content } else { sheet }
        }
        .onAppear(perform: restore)
        .onDisappear(perform: park)
        .onChange(of: tab, initial: true) { _, new in
            if new == .search && search == nil, let detail, let episode { search = makeSearch(detail, episode) }
        }
    }

    private var sheet: some View {
        NavigationStack {
            content
                .background(Theme.panel)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { SheetCancelButton(title: "Close") { dismiss() } }
                    ToolbarItem(placement: .principal) { EpisodeCodeLabel(code: code) }
                    if canSearch {
                        ToolbarItem(placement: .primaryAction) {
                            EpisodeAutoSearchItem(label: searchLabel, code: code, editionId: store.scopeEditionId,
                                                  episodeId: target.episodeId)
                        }
                    }
                }
        }
        .presentationDragIndicator(.visible)
        .sheetBackground(Theme.panel)
    }

    private var content: some View {
        VStack(spacing: 0) {
            if let detail, let episode {
                if inline { pageBar }
                EpisodeHeading(episode: episode)
                    .padding(.horizontal, gutter)
                    .padding(.top, inline ? 4 : 8)
                    .padding(.bottom, 14)
                Picker("Episode detail", selection: $tab) {
                    ForEach(EpisodeSheetTab.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, gutter)
                .padding(.bottom, 10)
                pane(detail, episode)
                    .id(tab)
                    .transition(.opacity)
            } else {
                EmptyBox(message: "This episode is no longer in the library.").padding(gutter)
                Spacer()
            }
        }
        .detailAnimation(.easeInOut(duration: 0.18), value: tab)
    }

    /// The right page's bar: the code, then Auto search (no Close: the
    /// title column's closes the episode first).
    private var pageBar: some View {
        HStack(spacing: 12) {
            EpisodeCodeLabel(code: code)
            Spacer(minLength: 8)
            if canSearch {
                SearchActionButton(label: searchLabel, editionId: store.scopeEditionId, episodeId: target.episodeId,
                                   accessibility: "Auto search \(code)", title: "Auto search")
            }
        }
        .frame(minHeight: 44)
        .padding(.horizontal, gutter)
        .padding(.top, 12)
        .padding(.bottom, 6)
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

    @ViewBuilder
    private func pane(_ detail: ItemDetail, _ episode: Episode) -> some View {
        switch tab {
        case .details:
            ScrollView {
                EpisodeDetailsPane(detail: detail, episode: episode, seasonNumber: target.seasonNumber)
                    .padding(gutter)
            }
            .pullClosesPage(inline)
        case .history:
            ScrollView {
                EpisodeHistoryPane(detail: detail, episode: episode, seasonNumber: target.seasonNumber)
                    .padding(gutter)
            }
            .pullClosesPage(inline)
        case .search:
            if let search { InteractiveSearchPane(model: search) } else { Spacer() }
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
