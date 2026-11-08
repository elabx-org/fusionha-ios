import SwiftUI
import FusionhaKit

/// The sheets over a v2 title (slice S6b). The mock (browse-sheets.js)
/// restyles Interactive search, the Grab anyway decision and Delete; those
/// are v2's here, as is Manage episodes (a series' files by season on the
/// title's wash, `V2ManageEpisodesSheet`) and Needs you's Fix mode
/// (`V2ReviewFilesSheet`). Edit, Add version and a movie's
/// Manage files are already native forms in system sheets, so they stay v1's, as does
/// every other sheet (`DetailActionSheets`), restyled under v2 as one form
/// sheet (Look Pass family 1). Season actions are v2's menu
/// (`V2SeasonActionsMenu`), so v1's season sheet never shows. The episode sheet never shows:
/// v2 pushes the episode page instead (`v2TitleDestinations`).
struct V2TitleSheets: ViewModifier {
    let presenter: DetailPresenter
    let reduceMotion: Bool
    private var store: DetailStore { presenter.store }

    func body(content: Content) -> some View {
        content
            .duoPageSheet(item: presenter.item(\.interactive)) { target in
                V2InteractiveSearchSheet(target: target)
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
            .duoPageSheet(isPresented: presenter.flag(\.showingDelete)) {
                if let detail = store.detail {
                    V2DeleteSheet(detail: detail)
                        .environment(store)
                        .presentationDetents([.medium, .large])
                }
            }
            .duoPageSheet(item: presenter.item(\.manageFiles)) { target in
                if let detail = store.detail {
                    if target.problems {
                        // Needs you's Review: Fix mode, for a series or a movie.
                        V2ReviewFilesSheet(detail: detail, target: target)
                            .environment(store)
                    } else if detail.isSeries {
                        V2ManageEpisodesSheet(detail: detail, target: target)
                            .environment(store)
                    } else {
                        ManageFilesSheet(detail: detail, target: target)
                            .environment(store)
                    }
                }
            }
            .modifier(V2TitleGroupSheets(presenter: presenter))
            .modifier(V2SearchScreenshot(store: presenter.store))
            .modifier(DetailActionSheets(presenter: presenter, episodeInline: true, ownsManageFiles: true))
    }
}
