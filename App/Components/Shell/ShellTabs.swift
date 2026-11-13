import SwiftUI
import FusionhaKit

/// The shell's tabs (`RootView`): the whole app when folded, the leading
/// column when unfolded. v2 (`\.shellChrome`) counts Activity's badge as
/// what needs you, in orange. Every tab always shows, folded and open (the
/// owner removed S14's column minimize, 2026-11-06).
struct ShellTabs: View {
    @Environment(AppModel.self) private var model
    @Environment(\.shellChrome) private var chrome
    @Environment(\.libraryTabRoot) private var libraryRoot
    let fold: FoldInfo
    let splitShown: Bool
    /// The list shows beside an open title (not hidden or parked under it).
    let listBesideTitle: Bool
    let downloadsBar: DownloadsBarState
    /// The system's downloads bar may show (not across the fold, not over a bulk bar).
    let downloadsBarAllowed: Bool
    /// What needs you on the queue, kept off the 2s poll's re-renders.
    @State private var needYou = 0
    @Environment(\.horizontalSizeClass) private var sizeClass
    /// The tabs' own width (the list pane's on the open Duo).
    @State private var width: CGFloat = 0
    /// v2, on trial (Account): the Duo's tabs collapse into an arrow button.
    @AppStorage(TabsLook.collapsedKey) private var collapsedPref = false
    @AppStorage(TabsLook.bottomKey) private var arrowAtBottom = false
    /// The Duo's column: the trailing safe-area inset.
    @State private var column: CGFloat = 0

    /// Collapsed on the Duo, folded or open, with or without a title open.
    /// It used to end while a title was open: opening one over a hidden
    /// list then brought the tab bar back and re-flowed the whole page
    /// under the title as it slid in (owner, build 1149: "resizing jitter
    /// and flicker"). The page under a full-width title now keeps its
    /// layout. With the list showing beside a title the tab bar comes back
    /// in the list pane (as before 1151): hiding it there, with a search
    /// field active in that pane, is the suspect for the freeze and crash on
    /// opening a filtered or searched result (owner, build 1155).
    private var collapsed: Bool {
        chrome != nil && collapsedPref && !listBesideTitle
            && (fold.isDuoOpen || OuterDisplay.isFoldedDuo(sizeClass: sizeClass))
    }

    /// v2 in the open Duo's narrow list pane (owner 2026-11-09): the tabs
    /// show their icons only (the five labels were cut off at about 290pt).
    /// The owner chose Search apart (option C), but the system keeps a
    /// regular-width bar's search tab inline, so it is an icon like the rest.
    /// The phone and the folded Duo keep their labels.
    private var narrowColumn: Bool {
        chrome != nil && splitShown && sizeClass == .regular && width > 0 && width < 420
    }

    /// The iPhone Duo, folded or open: the tabs and the page's buttons live
    /// in the system column there.
    private var onDuo: Bool { fold.isDuoOpen || OuterDisplay.isFoldedDuo(sizeClass: sizeClass) }

    private var tabsState: CollapsedTabsState {
        CollapsedTabsState(on: collapsed, bottom: arrowAtBottom, activity: activityBadge, requests: model.requestsBadge)
    }

    /// A tab's title: empty in the narrow column, where the icon stands alone
    /// and VoiceOver still reads the name (`.accessibilityLabel`).
    private func title(_ name: String) -> String { narrowColumn ? "" : name }

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
                Tab(title("Discover"), image: "nav-discover", value: AppTab.discover) { TabRoot { DiscoverView() } }
                    .accessibilityLabel(Text("Discover"))
                Tab(title("My requests"), image: "nav-requests", value: AppTab.requests) { TabRoot { RequestsView() } }
                    .accessibilityLabel(Text("My requests"))
                Tab(title("You"), image: "nav-you", value: AppTab.you) { TabRoot { YouView() } }
                    .accessibilityLabel(Text("You"))
                Tab(title("Search"), systemImage: "magnifyingglass", value: AppTab.search, role: .search) {
                    TabRoot { SearchTabView() }
                }
                .accessibilityLabel(Text("Search"))
            } else {
                if let title = libraryRoot?.title, let symbol = libraryRoot?.systemImage {
                    Tab(self.title(title), systemImage: symbol, value: AppTab.library) { TabRoot { LibraryTabRoot() } }
                        .accessibilityLabel(Text(title))
                } else {
                    Tab(title("Library"), image: "nav-library", value: AppTab.library) { TabRoot { LibraryTabRoot() } }
                        .accessibilityLabel(Text("Library"))
                }
                Tab(title("Discover"), image: "nav-discover", value: AppTab.discover) { TabRoot { DiscoverView() } }
                    .accessibilityLabel(Text("Discover"))
                    // `needs_you`, capped at 99+ like the web's badge.
                    .badge(BadgeCount.text(model.requestsBadge).map { Text(verbatim: $0) })
                Tab(title("Calendar"), image: "nav-calendar", value: AppTab.calendar) { TabRoot { CalendarView() } }
                    .accessibilityLabel(Text("Calendar"))
                Tab(title("Activity"), image: "nav-activity", value: AppTab.activity) { TabRoot { ActivityView() } }
                    .accessibilityLabel(Text("Activity"))
                    .badge(BadgeCount.text(activityBadge).map { Text(verbatim: $0) })
                Tab(title("Search"), systemImage: "magnifyingglass", value: AppTab.search, role: .search) {
                    TabRoot { SearchTabView() }
                }
                .accessibilityLabel(Text("Search"))
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width.rounded() } action: { width = $0 }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.trailing } action: { column = $0 }
        .environment(\.collapsedTabs, tabsState)
        .tint(Theme.indigo)
        // Count badges in the accent, as on the web, not the system red; the
        // shell's size re-tints them after the bar changes axis. v2's
        // Activity count is what needs you, in orange.
        .tabBadgeTint(key: "\(model.requestsBadge)-\(activityBadge)-\(model.tab)-\(Int(fold.size.width))x\(Int(fold.size.height))-\(splitShown)-\(narrowColumn)",
                      fills: chrome?.activityBadgeNeedsYou == true ? ["Activity": Theme.stuck] : [:])
        // The phone's tab bar still tucks away on scroll. On the Duo the bar
        // is the column, which the owner keeps always showing (2026-11-06):
        // its minimize also folded away the title's buttons, and with them
        // the More menu open from one of them (owner, build 1174 IMG_8020:
        // scrolling the menu collapsed the bar and closed the menu).
        .tabBarMinimizeBehavior(onDuo ? .never : .onScrollDown)
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
