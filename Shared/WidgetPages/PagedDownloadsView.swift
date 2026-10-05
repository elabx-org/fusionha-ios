import SwiftUI
import WidgetKit
import FusionhaKit

/// The medium and large Downloads widget: a header with the view's name and
/// the page dots (tap to flick to the next view), then the current view.
struct PagedDownloadsView: View {
    let entry: DownloadsEntry
    let family: WidgetFamily
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var large: Bool { family == .systemLarge }
    private var pages: [WidgetPage] { entry.pages.isEmpty ? [entry.page] : entry.pages }

    var body: some View {
        VStack(alignment: .leading, spacing: large ? 8 : 6) {
            WidgetPageHeader(entry: entry, pages: pages, familyKey: WidgetPageStore.familyKey(family))
            Group {
                if entry.failed {
                    WidgetEmptyText("Server unreachable")
                } else {
                    content
                }
            }
            .id(entry.page)
            .transition(reduceMotion ? .opacity : .push(from: .trailing))
            .invalidatableContent()
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var content: some View {
        let data = entry.pageData
        switch entry.page {
        case .downloading: WidgetDownloadingPage(rows: entry.rows, large: large)
        case .upNext: WidgetUpNextPage(rows: entry.upNext, large: large)
        case .recent: WidgetRecentPage(rows: entry.recent, large: large)
        case .library: WidgetLibraryPage(summary: data.library, large: large)
        case .indexers: WidgetIndexersPage(summary: data.indexers, large: large)
        case .wanted: WidgetWantedPage(summary: data.wanted, posters: data.wantedPosters, large: large)
        case .requests: WidgetRequestsPage(data: data, large: large)
        }
    }
}
