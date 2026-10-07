import SwiftUI
import WidgetKit
import FusionhaKit

/// The medium and large Downloads widget: the compact header with the view's
/// name, its status figure and the page dots (tap to flick to the next view),
/// then the current view.
struct PagedDownloadsView: View {
    let entry: DownloadsEntry
    let family: WidgetFamily
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var large: Bool { family == .systemLarge }
    private var pages: [WidgetPage] { entry.pages.isEmpty ? [entry.page] : entry.pages }

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetStyle.headerGap) {
            WidgetPageHeader(entry: entry, pages: pages, familyKey: familyKey)
            WidgetPageContent(entry: entry, large: large, familyKey: familyKey)
                .id(entry.page)
                .transition(reduceMotion ? .opacity : .push(from: .trailing))
                .invalidatableContent()
                .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var familyKey: String { WidgetPageStore.familyKey(family) }
}
