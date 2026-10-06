import SwiftUI
import WidgetKit
import FusionhaKit

/// The paged widget's header: the shared compact header (glyph, the view's
/// name, its status figure) with Process queue on Downloading and the page dots.
struct WidgetPageHeader: View {
    let entry: DownloadsEntry
    let pages: [WidgetPage]
    let familyKey: String

    var body: some View {
        let figure = entry.pageFigure
        WidgetTopBar(title: entry.page.title, figure: figure?.text, tint: figure?.tint ?? .secondary) {
            if entry.page == .downloading { ProcessQueueButton() }
            if pages.count > 1 {
                WidgetPageDots(pages: pages, current: entry.page, familyKey: familyKey)
            }
        }
    }
}

extension WidgetPage {
    var tint: Color {
        switch self {
        case .downloading: return Theme.grab
        case .upNext: return Theme.unaired
        case .recent: return Theme.done
        case .library: return Theme.i2
        case .indexers: return Theme.indigo
        case .wanted: return Theme.miss
        case .requests: return Theme.edition
        }
    }
}
