import SwiftUI
import WidgetKit

@main
struct FusionhaWidgetsBundle: WidgetBundle {
    #if V2
    // v2 adds Needs you. Every other kind is v1's, unchanged, so the widgets a
    // v1 install placed keep working when v2 takes its place (docs/v2.md).
    var body: some Widget {
        DownloadsWidget()
        UpNextWidget()
        RecentWidget()
        // One view each, for stacking (Smart Stack).
        DownloadingWidget()
        LibraryWidget()
        IndexersWidget()
        RequestsWidget()
        NeedsYouWidget()
        DownloadsLiveActivity()
    }
    #else
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
    #endif
}
