import SwiftUI
import FusionhaKit

/// The app shell, mirroring the web's mobile layout: the five bottom-nav
/// destinations (Library, Discover, Calendar, Activity, Wanted) with the web's
/// icons in the native Liquid Glass tab bar, which hides on scroll like the
/// web's floating bar. Requester accounts get Discover, My requests and You.
/// Item details and Add open as sheets, as they do on the web.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.tab) {
            if model.requestScoped {
                Tab("Discover", image: "nav-discover", value: AppTab.discover) { DiscoverView() }
                Tab("My requests", image: "nav-requests", value: AppTab.requests) { RequestsView() }
                Tab("You", image: "nav-you", value: AppTab.you) { YouView() }
            } else {
                Tab("Library", image: "nav-library", value: AppTab.library) { LibraryView() }
                Tab("Discover", image: "nav-discover", value: AppTab.discover) { DiscoverView() }
                Tab("Calendar", image: "nav-calendar", value: AppTab.calendar) { CalendarView() }
                Tab("Activity", image: "nav-activity", value: AppTab.activity) { ActivityView() }
                    .badge(model.queueTotal)
                Tab("Wanted", image: "nav-wanted", value: AppTab.wanted) { WantedView() }
            }
        }
        .tint(Theme.cyan)
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(item: $model.presentedItem) { ref in
            ItemDetailView(itemId: ref.id)
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.bg)
        }
        .sheet(isPresented: $model.showingAdd) {
            AddTitleSheet()
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.panel)
        }
        .sheet(isPresented: $model.showingAccount) { AccountSheet().presentationBackground(Theme.bg) }
        .onOpenURL { url in
            // fusionha://activity from the widget and Live Activity.
            if url.host() == "activity" { model.tab = .activity }
        }
        .onChange(of: model.tab) { model.searchText = "" }
        .task { await model.loadMe() }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await model.pollQueue()
        }
    }
}

/// Wraps a tab's content in the web's mobile chrome: the sticky top bar
/// (logo, search pill, avatar), the dark page background, the top-bar search
/// results and, where the web shows it, the gradient + button.
struct Screen<Content: View>: View {
    @Environment(AppModel.self) private var model
    var showsAdd = false
    /// Library filters its grid in place for "This library" searches.
    var filtersInPlace = false
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            if showingResults {
                OmniSearchResults()
                    .transition(.opacity)
            } else if showsAdd && !model.requestScoped && model.me?.can("add") != false {
                AddButton { model.showingAdd = true }
                    .padding(.trailing, 16)
                    .padding(.bottom, 12)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { TopBar() }
        .webBackground()
        .animation(.smooth(duration: 0.2), value: showingResults)
    }

    private var showingResults: Bool {
        let typing = !model.searchText.trimmingCharacters(in: .whitespaces).isEmpty
        return typing && !(filtersInPlace && model.searchScope == .library)
    }
}

/// The web's mobile `Fab`: a 56pt gradient orb with a plus.
struct AddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Theme.fusion, in: Circle())
                .shadow(color: .black.opacity(0.5), radius: 12, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add title")
    }
}
