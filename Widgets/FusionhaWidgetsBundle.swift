import SwiftUI
import WidgetKit

@main
struct FusionhaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DownloadsWidget()
        UpNextWidget()
        RecentWidget()
        // One view each, for stacking (Smart Stack).
        DownloadingWidget()
        LibraryWidget()
        IndexersWidget()
        RequestsWidget()
        DownloadsLiveActivity()
    }
}
