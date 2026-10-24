import SwiftUI
import FusionhaKit

/// The app shell, mirroring the web's mobile layout: Library, Discover,
/// Calendar and Activity (Wanted is an Activity tab) with the web's icons in
/// the native Liquid Glass tab bar, plus the iOS 26 search tab, which hides on scroll like the
/// web's floating bar. Requester accounts get Discover, My requests and You.
/// Item details, Add, the omni search and the Delete confirmation open as
/// sheets, and toasts float above the tab bar, as they do on the web (on the
/// trailing column when the shell is split).
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fold = FoldInfo()
    @State private var toastAnchor = ToastAnchor()
    /// iPhone Duo open: Spread (two pages at the fold) or the Web layout. Per device.
    @AppStorage(DuoOpenLayout.storageKey) private var duoLayout: DuoOpenLayout = .standard
    @State private var spanRequests = SpreadSpanRequests()
    @State private var downloadsBar = DownloadsBarState()
    /// The tabs whose list the sidebar button hid (`DuoListMemory`). Per device.
    @AppStorage(DuoListMemory.storageKey) private var hiddenLists = ""

    /// The Spread, when the Duo is open and the setting says so (else `.off`).
    private func spreadContext(_ fold: FoldInfo, hasItem: Bool) -> SpreadContext {
        SpreadContext(fold: fold, layout: duoLayout, spanRequested: spanRequests.spans(model.tab), hasItem: hasItem)
    }

    /// With room for two columns the open title is the trailing column, not a
    /// sheet; in a Spread the right page.
    private var split: ShellSplit {
        let hasItem = model.rightPageHasItem
        var split = ShellSplit(fold: fold, hasItem: hasItem, spread: spreadContext(fold, hasItem: hasItem))
        split.primaryHidden = split.axis == .horizontal && DuoSplit.hidesList(
            remembered: DuoListMemory(raw: hiddenLists).isHidden(model.tab.listMemoryKey),
            posture: fold.posture, detailShown: split.shown && hasItem)
        return split
    }

    /// The sidebar button's action for the detail column: offered flat open
    /// with a title or preview beside the list (`DuoSplit.hidesList`).
    private func listToggle(_ split: ShellSplit) -> DuoListToggle? {
        guard split.shown, split.axis == .horizontal, fold.posture?.canHideList == true,
              model.rightPageHasItem else { return nil }
        let key = model.tab.listMemoryKey
        return DuoListToggle(hidden: split.primaryHidden) {
            var memory = DuoListMemory(raw: hiddenLists)
            memory.toggle(key)
            hiddenLists = memory.raw
        }
    }

    /// The tabs' column runs across the Duo's fold in book pose (a Spread
    /// span, or the Web layout with nothing open): the system-hosted downloads
    /// bar would sit on the fold there, so it waits until a title takes the
    /// right page. Flat open nothing is reserved.
    private var tabsCrossFold: Bool {
        let split = split
        return SpreadGeometry.tabsCrossFold(tabsWidth: Double(split.shown ? split.primary : fold.size.width),
                                            fold: fold.vertical.map { Double($0.lowerBound)...Double($0.upperBound) })
    }

    /// The title's column coming in: a short fade and 24 pt rise on the open
    /// Duo (its own animation, as the split itself doesn't animate there), a
    /// slide elsewhere, a plain fade under Reduce Motion.
    private var detailTransition: AnyTransition {
        if reduceMotion { return .opacity.animation(.easeOut(duration: 0.2)) }
        guard fold.isDuoOpen else { return .move(edge: .trailing).combined(with: .opacity) }
        return .opacity.combined(with: .offset(x: 24)).animation(.easeOut(duration: 0.22))
    }

    /// Whether an open title would be a column (not a sheet) in this geometry.
    private func splitsWithTitle(_ fold: FoldInfo) -> Bool {
        ShellSplit(fold: fold, hasItem: true, spread: spreadContext(fold, hasItem: true)).shown
    }

    /// The detail sheet's binding: empty while the title shows in the trailing
    /// column, so unfolding moves an open sheet into the column and folding
    /// moves it back, without losing which title is open.
    private var sheetItem: Binding<ItemRef?> {
        Binding(
            get: { split.shown ? nil : model.presentedItem },
            set: { value in if !split.shown { model.presentedItem = value } }
        )
    }

    var body: some View {
        let split = split
        let spread = spreadContext(fold, hasItem: model.rightPageHasItem)
        FoldSplitLayout(axis: split.axis, primary: split.primary, gap: split.gap, primaryHidden: split.primaryHidden) {
            // Hidden (the sidebar button), the list keeps its width off screen.
            tabs
                .allowsHitTesting(!split.primaryHidden)
                .accessibilityHidden(split.primaryHidden)
            if split.shown {
                ShellDetailColumn()
                    .transition(detailTransition)
            }
        }
        .background(Theme.bg)
        // Measured without the keyboard: typing in inner landscape must not
        // drop the height under the split rule and fold the title into a sheet.
        .background {
            Color.clear
                .ignoresSafeArea(.keyboard)
                .onGeometryChange(for: FoldInfo.self) { FoldInfo($0) } action: { newFold in
                    model.updateDetailHost(splitsWithTitle: splitsWithTitle(newFold))
                    fold = newFold
                }
        }
        // Spread <-> Web layout keeps the tab, its scroll and the open title (DC3):
        // the same split container, the title's store in the model.
        .onChange(of: duoLayout) { model.updateDetailHost(splitsWithTitle: splitsWithTitle(fold)) }
        // A preview on the right page goes back to its tab's sheet when the
        // Spread ends (`SpreadPreviewHost`); one left on another tab closes.
        .onChange(of: spread.isActive) { _, active in if !active { model.settleSpreadPreview() } }
        // On the open Duo the tabs' column jumps to its new width (a Spread
        // span to the left page re-flows the whole Library grid, and animating
        // that relayout stuttered); only the title's column animates, through
        // its own transition. Elsewhere the split still slides. The sidebar
        // button's hide / show slides (the inner modifier wins): the list
        // keeps its width, so nothing in it re-flows.
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: split.primaryHidden)
        .animation(reduceMotion || fold.isDuoOpen ? nil : .smooth(duration: 0.3), value: split)
        // Toasts: above the tab bar when folded; on the trailing column when
        // split, so they never straddle the fold (DC14); on the right page
        // while a Spread's tab spans both pages.
        .overlay {
            ToastLayer(region: ToastRegion.shell(split, spread: spread, size: fold.size),
                       clearsAbove: split.shown || spread.spans ? nil : toastAnchor.floor, gap: 16)
        }
        .environment(toastAnchor)
        .environment(\.spread, spread)
        .environment(\.duoListToggle, listToggle(split))
        .environment(\.duoOpen, fold.isDuoOpen)
        .environment(\.spreadSpanRequests, spanRequests)
        .environment(\.bookPose, fold.vertical != nil)
        .environment(\.motionEnabled, !reduceMotion && model.animationsEnabled)
        .environment(\.railStyle, model.railStyle)
        .environment(\.railConsolidate, model.railConsolidate)
        .sheet(item: sheetItem, onDismiss: { DetailSheetPresence.dismissed() }) { ref in
            // A stack of its own, so Close, Refresh and Open in the web app are
            // system toolbar items over the art (DC10, ruling Q-DC8).
            NavigationStack { ItemDetailView(store: model.detailStore(for: ref.id)) }
                .onAppear {
                    DetailSheetPresence.shown()
                    DeepLinkProbe.log("detail \(ref.id) shown")
                }
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.bg)
        }
        .modifier(ShellPresentations(model: model, reduceMotion: reduceMotion, scenePhase: scenePhase,
                                     duoOpen: fold.isDuoOpen, accountOnPages: fold.isDuoOpen && duoLayout == .spread,
                                     measured: fold.size != .zero))
    }

    /// The tabs: the whole app when folded, the leading column when unfolded.
    private var tabs: some View {
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
                Tab("Library", image: "nav-library", value: AppTab.library) { TabRoot { LibraryView() } }
                Tab("Discover", image: "nav-discover", value: AppTab.discover) { TabRoot { DiscoverView() } }
                    // `needs_you`, capped at 99+ like the web's badge.
                    .badge(BadgeCount.text(model.requestsBadge).map { Text(verbatim: $0) })
                Tab("Calendar", image: "nav-calendar", value: AppTab.calendar) { TabRoot { CalendarView() } }
                Tab("Activity", image: "nav-activity", value: AppTab.activity) { TabRoot { ActivityView() } }
                    .badge(BadgeCount.text(model.queueTotal).map { Text(verbatim: $0) })
                Tab(value: AppTab.search, role: .search) { TabRoot { SearchTabView() } }
            }
        }
        .tint(Theme.indigo)
        // Count badges in the accent, as on the web, not the system red; the
        // shell's size re-tints them after the bar changes axis.
        .tabBadgeTint(key: "\(model.requestsBadge)-\(model.queueTotal)-\(model.tab)-\(Int(fold.size.width))x\(Int(fold.size.height))-\(split.shown)")
        .tabBarMinimizeBehavior(.onScrollDown)
        // The downloads bar (iOS-only): while the queue has items, off Activity,
        // and never across the iPhone Duo's fold (the Activity badge still counts).
        .modifier(DownloadsBarSlot(state: downloadsBar,
                                   shown: !model.requestScoped && model.tab != .activity && downloadsBar.hasContent
                                       && !tabsCrossFold))
        .onChange(of: model.queue, initial: true) { downloadsBar.update(model.queue) }
    }
}

/// Wraps a tab's content in the page background. The title, the Account item
/// and the page's actions are in the system bar (`.shellPage(_:)`); where the
/// web shows its mobile "+" it is `AddTitleToolbarItem` there.
struct Screen<Content: View>: View {
    @Environment(AppModel.self) private var model
    /// Kept for source compatibility: pages that add place `AddTitleToolbarItem`.
    var showsAdd = false
    /// Kept for source compatibility: Library filters in place through the
    /// top-bar pill, every other tab opens the omni search.
    var filtersInPlace = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .overlay(alignment: .top) {
                if !model.requestScoped { SetupProgressPill(barHeight: 0) }
            }
            .webBackground()
    }
}

/// The "+" of Library, Discover and Wanted as a toolbar item (D1; it replaced
/// the title row's glass "+"). Opens the Add sheet. Absent for request-scoped
/// sessions, without the add capability, and while selecting.
struct AddTitleToolbarItem: ToolbarContent {
    let model: AppModel

    var body: some ToolbarContent {
        if !model.requestScoped && model.me?.can("add") != false && !model.selectMode {
            ToolbarItem(placement: .primaryAction) {
                Button("Add", systemImage: "plus") { model.showingAdd = true }
            }
            .barPriority(true)
        }
    }
}
