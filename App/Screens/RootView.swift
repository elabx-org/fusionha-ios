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

    /// With room for two columns the open title is the trailing column, not a sheet.
    private var split: ShellSplit {
        ShellSplit(fold: fold, hasItem: model.presentedItem != nil)
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
                    model.updateDetailHost(splitsWithTitle: ShellSplit(fold: newFold, hasItem: true).shown)
                    fold = newFold
                }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: split)
        // Toasts: above the tab bar when folded; on the trailing column when
        // split, so they never straddle the fold (DC14).
        .overlay {
            ToastLayer(region: ToastRegion.shell(split, size: fold.size),
                       clearsAbove: split.shown ? nil : toastAnchor.floor, gap: 16)
        }
        .environment(toastAnchor)
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
        .modifier(ShellPresentations(model: model, reduceMotion: reduceMotion, scenePhase: scenePhase))
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
    }
}

/// The shell's other sheets, deep links and polling, applied once around the
/// whole (possibly two-column) shell.
private struct ShellPresentations: ViewModifier {
    @Bindable var model: AppModel
    let reduceMotion: Bool
    let scenePhase: ScenePhase

    func body(content: Content) -> some View {
        content
        .sheet(isPresented: $model.showingAdd) {
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

/// The web's DeleteItemDialog: "Delete {title}?", the delete-files checkbox, Cancel /
/// Delete (danger, "Deleting…" while pending).
struct DeleteTitleDialog: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let target: DeleteTarget
    @State private var deleteFiles = false
    @State private var deleting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Delete \(target.title)?")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.txt)
                .padding(.top, 8)
            Text("This removes the title and all its versions from your library. This cannot be undone.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
            Toggle(isOn: $deleteFiles) {
                Text("Also delete the downloaded files from disk")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Theme.txt)
            }
            .toggleStyle(WebCheckboxStyle())
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.txt)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .panel(Theme.panel2, radius: Theme.radius)
                }
                .buttonStyle(PressScaleStyle())
                Button {
                    Task {
                        deleting = true
                        let ok = await model.delete(target, deleteFiles: deleteFiles)
                        deleting = false
                        if ok { dismiss() }
                    }
                } label: {
                    Text(deleting ? "Deleting…" : "Delete")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.onDanger)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Theme.danger, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                }
                .buttonStyle(PressScaleStyle())
                .disabled(deleting)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A web checkbox: an 18pt rounded square, indigo with a white tick when on.
struct WebCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(configuration.isOn ? Theme.indigo : Color.clear)
                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(configuration.isOn ? Theme.indigo : Theme.mut.opacity(0.6), lineWidth: 1.5))
                    .overlay {
                        if configuration.isOn {
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(Theme.onAccent)
                        }
                    }
                    .frame(width: 18, height: 18)
                configuration.label
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
