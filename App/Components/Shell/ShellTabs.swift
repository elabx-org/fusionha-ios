import SwiftUI
import FusionhaKit

/// The shell's tabs (`RootView`): the whole app when folded, the leading
/// column when unfolded. v2 (`\.shellChrome`) counts Activity's badge as
/// what needs you, in orange. Every tab always shows, folded and open (the
/// owner removed S14's column minimize, 2026-11-06).
struct ShellTabs: View {
    @Environment(AppModel.self) private var model
    @Environment(\.shellChrome) private var chrome
    let fold: FoldInfo
    let splitShown: Bool
    let downloadsBar: DownloadsBarState
    /// The system's downloads bar may show (not across the fold, not over a bulk bar).
    let downloadsBarAllowed: Bool
    /// What needs you on the queue, kept off the 2s poll's re-renders.
    @State private var needYou = 0

    /// Activity's badge: the whole queue (v1) or what needs you (v2).
    private var activityBadge: Int {
        guard chrome?.activityBadgeNeedsYou == true else { return model.queueTotal }
        return needYou
    }

    var body: some View {
        @Bindable var model = model
        // A custom binding so tapping the current tab again still reaches the model.
        let selection = Binding(get: { model.tab }, set: { model.tab = $0 })
        return TabView(selection: selection) {
            if model.requestScoped {
                Tab("Discover", image: "nav-discover", value: AppTab.discover) { TabRoot { DiscoverView() } }
                Tab("My requests", image: "nav-requests", value: AppTab.requests) { TabRoot { RequestsView() } }
                Tab("You", image: "nav-you", value: AppTab.you) { TabRoot { YouView() } }
                Tab(value: AppTab.search, role: .search) { TabRoot { SearchTabView() } }
            } else {
                Tab("Library", image: "nav-library", value: AppTab.library) { TabRoot { LibraryTabRoot() } }
                Tab("Discover", image: "nav-discover", value: AppTab.discover) { TabRoot { DiscoverView() } }
                    // `needs_you`, capped at 99+ like the web's badge.
                    .badge(BadgeCount.text(model.requestsBadge).map { Text(verbatim: $0) })
                Tab("Calendar", image: "nav-calendar", value: AppTab.calendar) { TabRoot { CalendarView() } }
                Tab("Activity", image: "nav-activity", value: AppTab.activity) { TabRoot { ActivityView() } }
                    .badge(BadgeCount.text(activityBadge).map { Text(verbatim: $0) })
                Tab(value: AppTab.search, role: .search) { TabRoot { SearchTabView() } }
            }
        }
        .tint(Theme.indigo)
        // Count badges in the accent, as on the web, not the system red; the
        // shell's size re-tints them after the bar changes axis. v2's
        // Activity count is what needs you, in orange.
        .tabBadgeTint(key: "\(model.requestsBadge)-\(activityBadge)-\(model.tab)-\(Int(fold.size.width))x\(Int(fold.size.height))-\(splitShown)",
                      fills: chrome?.activityBadgeNeedsYou == true ? ["Activity": Theme.stuck] : [:])
        .tabBarMinimizeBehavior(.onScrollDown)
        // The downloads bar (iOS-only): while the queue has items, off Activity,
        // never across the iPhone Duo's fold (the Activity badge still counts),
        // and never over a select mode's bulk bar (`SelectBarPresence`).
        .modifier(DownloadsBarSlot(state: downloadsBar,
                                   shown: !model.requestScoped && model.tab != .activity && downloadsBar.hasContent
                                       && downloadsBarAllowed))
        .onQueueChange(model, initial: true) { [downloadsBar, need = $needYou] queue in
            downloadsBar.update(queue)
            // The queue's Needs you section, as Activity's own caption counts it.
            let count = queue.reduce(0) { $0 + (QueueSection.of($1) == .needs ? 1 : 0) }
            if need.wrappedValue != count { need.wrappedValue = count }
        }
    }
}
