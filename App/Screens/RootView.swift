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

    /// The Spread, when the Duo is open and the setting says so (else `.off`).
    private func spreadContext(_ fold: FoldInfo, hasItem: Bool) -> SpreadContext {
        SpreadContext(fold: fold, layout: duoLayout, spanRequested: spanRequests.spans(model.tab), hasItem: hasItem)
    }

    /// With room for two columns the open title is the trailing column, not a
    /// sheet; in a Spread the right page.
    private var split: ShellSplit {
        let hasItem = model.rightPageHasItem
        return ShellSplit(fold: fold, hasItem: hasItem, spread: spreadContext(fold, hasItem: hasItem))
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
        FoldSplitLayout(axis: split.axis, primary: split.primary, gap: split.gap) {
            tabs
            if split.shown {
                ShellDetailColumn()
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
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
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: split)
        // Toasts: above the tab bar when folded; on the trailing column when
        // split, so they never straddle the fold (DC14); on the right page
        // while a Spread's tab spans both pages.
        .overlay {
            ToastLayer(region: ToastRegion.shell(split, spread: spread, size: fold.size),
                       clearsAbove: split.shown || spread.spans ? nil : toastAnchor.floor, gap: 16)
        }
        .environment(toastAnchor)
        .environment(\.spread, spread)
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
                                     duoOpen: fold.isDuoOpen))
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
        // The downloads bar (iOS-only): while the queue has items, off Activity.
        .modifier(DownloadsBarSlot(state: downloadsBar,
                                   shown: !model.requestScoped && model.tab != .activity && downloadsBar.hasContent))
        .onChange(of: model.queue, initial: true) { downloadsBar.update(model.queue) }
    }
}

/// The shell's other sheets, deep links and polling, applied once around the
/// whole (possibly two-column) shell.
private struct ShellPresentations: ViewModifier {
    @Bindable var model: AppModel
    let reduceMotion: Bool
    let scenePhase: ScenePhase
    /// The iPhone Duo is open: the Add sheet goes on the right page.
    let duoOpen: Bool

    func body(content: Content) -> some View {
        content
        // On the open Duo, the right page (S3): never a form sheet on the fold.
        .duoPageSheet(isPresented: $model.showingAdd, onPages: duoOpen) {
            AddTitleSheet()
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
                .presentationBackground(Theme.panel)
        }
        .sheet(isPresented: $model.showingAccount, onDismiss: { model.avatar.openPending(model) }) {
            AccountSheet().presentationBackground(Theme.bg)
        }
        .modifier(AvatarPresentations(avatar: model.avatar, model: model))
        .modifier(SecretsLockedToaster(model: model))
        .sheet(item: $model.deleteTarget) { target in
            DeleteTitleDialog(target: target)
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.panel)
        }
        .onChange(of: model.pendingLink, initial: true) {
            // fusionha://activity, calendar, item/{id}… from the widgets, the
            // Live Activity and notifications (received in FusionhaApp).
            Task { await model.applyPendingLink() }
        }
        .onChange(of: model.tab) {
            model.searchText = ""
            model.chromeHidden = false
            if model.tab != .library { model.exitSelectMode() }
        }
        .task {
            #if DEBUG
            // CI screenshots: the folded iPhone Duo held sideways, when the
            // simulator cannot rotate itself (`FUSIONHA_SCREENSHOT_ORIENTATION=landscape`).
            if ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_ORIENTATION"] == "landscape",
               let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { _ in }
            }
            #endif
            await model.loadMe()
            await model.registerPushDevice()
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await model.pollQueue()
        }
        .task(id: "\(scenePhase == .active)|\(model.me?.id ?? -1)") {
            guard scenePhase == .active, model.me != nil else { return }
            await model.pollShell()
        }
        .task(id: "setups|\(scenePhase == .active)|\(model.me?.id ?? -1)") {
            guard scenePhase == .active, model.me != nil, !model.requestScoped else { return }
            await model.pollSetups()
        }
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
