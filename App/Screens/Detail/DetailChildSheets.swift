import SwiftUI
import FusionhaKit

/// Every sheet the item detail opens: interactive search, Edit, Add version,
/// season actions and Delete, plus the item actions rail's (ItemDetail.tsx
/// `modals`) Rename files, Edition aliases, Fix episode numbering, Manage
/// files, Switch metadata source, the episode sheet, Add collection and
/// Report an issue. Presented through `DetailPresenter`, so a fold /
/// unfold re-presents whichever was up on the new host.
struct DetailChildSheets: ViewModifier {
    let presenter: DetailPresenter
    let reduceMotion: Bool
    private var store: DetailStore { presenter.store }

    func body(content: Content) -> some View {
        content
            .duoPageSheet(item: presenter.item(\.interactive)) { target in
                InteractiveSearchSheet(target: target)
                    .environment(store)
                    .environment(\.detailReduceMotion, reduceMotion)
            }
            .duoPageSheet(isPresented: presenter.flag(\.showingEdit)) {
                if let detail = store.detail {
                    EditItemSheet(detail: detail)
                        .environment(store)
                }
            }
            .duoPageSheet(item: presenter.item(\.addPreset)) { preset in
                if let detail = store.detail {
                    AddEditionSheet(detail: detail, preset: preset)
                        .environment(store)
                }
            }
            .duoPageSheet(item: presenter.item(\.seasonSheet)) { ref in
                if let detail = store.detail, let season = detail.seasons?.first(where: { $0.seasonNumber == ref.number }) {
                    SeasonActionsSheet(detail: detail, season: season)
                        .environment(store)
                        .presentationDetents([.medium, .large])
                }
            }
            .duoPageSheet(isPresented: presenter.flag(\.showingDelete)) {
                if let detail = store.detail {
                    DeleteItemSheet(detail: detail)
                        .environment(store)
                        .presentationDetents([.height(300)])
                }
            }
            .modifier(DetailActionSheets(presenter: presenter))
    }
}

/// The item actions rail's sheets.
private struct DetailActionSheets: ViewModifier {
    let presenter: DetailPresenter
    private var store: DetailStore { presenter.store }

    func body(content: Content) -> some View {
        content
            .duoPageSheet(item: presenter.item(\.renameScope)) { scope in
                if let detail = store.detail {
                    RenameSheet(title: detail.title, scope: scope)
                        .environment(store)
                }
            }
            .duoPageSheet(isPresented: presenter.flag(\.showingAliases)) {
                if let detail = store.detail {
                    EditionAliasesSheet(detail: detail)
                        .environment(store)
                }
            }
            .duoPageSheet(isPresented: presenter.flag(\.showingNumbering)) {
                if let detail = store.detail {
                    NumberingFixSheet(detail: detail)
                        .environment(store)
                }
            }
            .duoPageSheet(item: presenter.item(\.manageFiles)) { target in
                if let detail = store.detail {
                    ManageFilesSheet(detail: detail, target: target)
                        .environment(store)
                }
            }
            .duoPageSheet(item: presenter.item(\.switchTarget)) { target in
                if let detail = store.detail {
                    MetadataSwitchSheet(detail: detail, target: target.provider)
                        .environment(store)
                }
            }
            .duoPageSheet(item: presenter.item(\.episodeSheet)) { target in
                EpisodeDetailSheet(target: target)
                    .environment(store)
            }
            .duoPageSheet(item: presenter.item(\.collectionAdd)) { target in
                AddCollectionSheet(summary: target.summary, preselect: target.tmdbIds) {
                    Task { await store.loadCollection() }
                }
            }
            .duoPageSheet(isPresented: presenter.flag(\.showingIssue)) {
                if let detail = store.detail {
                    IssueModal(mediaItemId: detail.id, title: detail.title, isSeries: detail.isSeries,
                               seasons: store.issueSeasons) { [store] message, failed in
                        store.show(message, variant: failed ? .error : .success)
                    }
                    .environment(store)
                }
            }
    }
}
