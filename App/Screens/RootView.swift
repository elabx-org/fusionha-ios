import SwiftUI

/// The app shell: the web's mobile bottom nav as a Liquid Glass tab bar, with
/// OmniSearch + Discover behind the separate search tab and the activity pulse
/// as a bottom accessory (like Music's mini player).
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.tab) {
            Tab("Library", systemImage: "square.grid.2x2", value: AppTab.library) {
                LibraryView()
            }
            Tab("Calendar", systemImage: "calendar", value: AppTab.calendar) {
                CalendarView()
            }
            Tab("Activity", systemImage: "arrow.down.circle", value: AppTab.activity) {
                ActivityView()
            }
            .badge(model.queueTotal)
            Tab("Wanted", systemImage: "tray.full", value: AppTab.wanted) {
                WantedView()
            }
            Tab("Search", systemImage: "magnifyingglass", value: AppTab.search, role: .search) {
                SearchView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            DownloadsAccessory()
        }
        .onOpenURL { url in
            // fusionha://activity from the widget and Live Activity.
            if url.host() == "activity" { model.tab = .activity }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await model.pollQueue()
        }
    }
}
