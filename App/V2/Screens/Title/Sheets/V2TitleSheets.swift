import SwiftUI
import FusionhaKit

/// The sheets over a v2 title (slice S6b). The mock (browse-sheets.js)
/// restyles Interactive search, the Grab anyway decision and Delete; those
/// are v2's here. Edit, Add version and Manage files are already native
/// forms in system sheets, the mock's look, so they stay v1's, as does
/// every other sheet (`DetailActionSheets`). The episode sheet never shows:
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
            .duoPageSheet(item: presenter.item(\.seasonSheet)) { ref in
                if let detail = store.detail, let season = detail.seasons?.first(where: { $0.seasonNumber == ref.number }) {
                    SeasonActionsSheet(detail: detail, season: season)
                        .environment(store)
                        .presentationDetents([.medium, .large])
                }
            }
            .duoPageSheet(isPresented: presenter.flag(\.showingDelete)) {
                if let detail = store.detail {
                    V2DeleteSheet(detail: detail)
                        .environment(store)
                        .presentationDetents([.medium, .large])
                }
            }
            .modifier(DetailActionSheets(presenter: presenter, episodeInline: true))
    }
}
