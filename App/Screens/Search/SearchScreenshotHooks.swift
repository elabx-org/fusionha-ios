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

/// CI screenshots: `FUSIONHA_SCREENSHOT_SEARCH_OPEN=<item id>` focuses the
/// field (the keyboard comes up), then opens that library title as its row
/// does: on the open Duo it must land in the right column and stay there
/// (build 781 looped sheet / keyboard).
private struct SearchScreenshotOpen: ViewModifier {
    @Environment(AppModel.self) private var model
    var focused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        content.task {
            guard let id = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_SEARCH_OPEN"].flatMap(Int.init) else { return }
            try? await Task.sleep(for: .seconds(1))
            focused.wrappedValue = true
            try? await Task.sleep(for: .seconds(2.5))
            model.open(id)
        }
    }
}

extension View {
    func searchScreenshotOpen(_ focused: FocusState<Bool>.Binding) -> some View {
        modifier(SearchScreenshotOpen(focused: focused))
    }

    func searchScreenshotPreview(search: UnifiedSearchModel, open: @escaping (MediaSearchResult) -> Void) -> some View {
        modifier(SearchScreenshotPreview(search: search, open: open))
    }
}
#endif
