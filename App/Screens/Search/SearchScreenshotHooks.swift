#if DEBUG
import SwiftUI
import FusionhaKit

/// CI screenshots: `FUSIONHA_SCREENSHOT_SEARCH_PREVIEW=<tmdb id>` opens that
/// add row's preview once its provider answers (the Duo harness's "preview
/// open" shot: the right page of a Spread, else the sheet).
private struct SearchScreenshotPreview: ViewModifier {
    let search: UnifiedSearchModel
    let open: (MediaSearchResult) -> Void
    @State private var done = false

    func body(content: Content) -> some View {
        content.onChange(of: search.lanes) {
            guard !done, let id = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_SEARCH_PREVIEW"].flatMap(Int.init),
                  let hit = search.lanes.add.compactMap(\.tmdb).first(where: { $0.tmdbId == id }) else { return }
            done = true
            open(hit)
        }
    }
}

extension View {
    func searchScreenshotPreview(search: UnifiedSearchModel, open: @escaping (MediaSearchResult) -> Void) -> some View {
        modifier(SearchScreenshotPreview(search: search, open: open))
    }
}
#endif
