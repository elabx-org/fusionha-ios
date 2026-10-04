import SwiftUI
import WidgetKit

@main
struct FusionhaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DownloadsWidget()
        UpNextWidget()
        RecentWidget()
        DownloadsLiveActivity()
    }
}
