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
    /// Bulk-select bars on screen: the downloads bar steps aside for them.
    @State private var selectBars = SelectBarPresence()
    /// iPhone Duo open: Spread (two pages at the fold) or the Web layout. Per device.
    @AppStorage(DuoOpenLayout.storageKey) private var duoLayout: DuoOpenLayout = .standard
    @State private var spanRequests = SpreadSpanRequests()
    @State private var downloadsBar = DownloadsBarState()
    /// The downloads pill's frame, for the tabs' bottom reserve (D3).
    @State private var pillSpace = DownloadsPillSpace()
    /// The tabs whose list the sidebar button hid (`DuoListMemory`). Per device.
    @AppStorage(DuoListMemory.storageKey) private var hiddenLists = ""
    /// v2's title page (`TitlePageHost`); nil in v1.
    @Environment(\.titlePage) private var titlePage
    /// v2's split handle moving the seam (`DuoSeamDrag`); never set in v1.
    @State private var seam = DuoSeamDrag()
    /// v2's badge and downloads capsule (`ShellChromeOverride`); nil in v1.
    @Environment(\.shellChrome) private var chrome

    /// The Spread, when the Duo is open and the setting says so (else `.off`).
    private func spreadContext(_ fold: FoldInfo, hasItem: Bool) -> SpreadContext {
        SpreadContext(fold: fold, layout: duoLayout, spanRequested: spanRequests.spans(model.tab), hasItem: hasItem)
    }

    /// With room for two columns the open title is the trailing column, not a
    /// sheet; in a Spread the right page.
    private var split: ShellSplit {
        let hasItem = model.rightPageHasItem
        let spread = spreadContext(fold, hasItem: hasItem)
        var split = ShellSplit(fold: fold, hasItem: hasItem, spread: spread)
        // An episode open beside its title takes the list's place (`TitleSpread`).
        split.primaryHidden = split.axis == .horizontal && (episodeBeside(split, spread: spread) || DuoSplit.hidesList(
            remembered: DuoListMemory(raw: hiddenLists).isHidden(model.tab.listMemoryKey),
            posture: fold.posture, detailShown: split.shown && hasItem))
        applyFlatOpenShare(&split)
        if let live = seam.live, let context = seamContext(split) {
            split.seam = context.seam(live: live)
        } else if slidePending(), let context = seamContext(split) {
            split.seam = context.slideInStart()
        }
        return split
    }

    /// v2: a title just opened that its handle will slide in (`V2SplitHandle.slideIn`)
    /// is laid out where the slide starts from the first frame: off the trailing
    /// edge, over the list at its full width. Before the handle appeared, that
    /// frame had the split at rest, so with the list remembered hidden the
    /// Library jumped (animated) toward its hidden place and back, and the
    /// title showed in the middle of it (owner, build 791).
    private func slidePending() -> Bool {
        guard !reduceMotion, model.animationsEnabled, !seam.handleShown,
              let id = model.presentedItem?.id else { return false }
        return seam.slidIn != id
    }

    /// v2 (`TitlePageOverride.flatOpenListShare`): the flat open Duo is one
    /// seamless display, so an open title takes the rest beside a list of
    /// that share, with no fold gutter. Book pose keeps the pages.
    private func applyFlatOpenShare(_ split: inout ShellSplit) {
        guard let share = titlePage?.flatOpenListShare, fold.vertical == nil, fold.flatVertical != nil,
              split.shown, split.axis == .horizontal, !split.primaryHidden, model.presentedItem != nil else { return }
        split.primary = (fold.size.width * CGFloat(share)).rounded()
        split.gap = 0
    }

    /// v2's split handle, where it is offered (`DuoSeamContext`); nil in v1.
    private func seamContext(_ split: ShellSplit) -> DuoSeamContext? {
        DuoSeamContext(titlePage: titlePage, fold: fold, split: split, toggle: listToggle(split), drag: seam, model: model)
    }

    /// A Spread with an episode open from the title: the title's tabs on the
    /// left page, the episode on the right, the list hidden until it closes.
    private func episodeBeside(_ split: ShellSplit, spread: SpreadContext) -> Bool {
        // v2's title page is one column: an episode never takes the list's place.
        guard titlePage == nil, split.shown, let ref = model.presentedItem,
              TitleSpread.pages(fold: fold, spread: spread) != nil else { return false }
        return model.detailStore(for: ref.id).episodeSheet != nil
    }

    /// The title's halves for its column (`TitleSpread`).
    private func titleSpread(_ split: ShellSplit, spread: SpreadContext) -> TitleSpread? {
        // v2's title page never splits at the fold.
        guard titlePage == nil, split.shown, split.axis == .horizontal, model.presentedItem != nil,
              let pages = TitleSpread.pages(fold: fold, spread: spread) else { return nil }
        return TitleSpread(pages: pages, fillsDisplay: split.primaryHidden)
    }

    /// The sidebar button's action for the detail column: offered flat open
    /// with a title or preview beside the list (`DuoSplit.hidesList`).
    private func listToggle(_ split: ShellSplit) -> DuoListToggle? {
        guard split.shown, split.axis == .horizontal, fold.posture?.canHideList == true,
              model.rightPageHasItem,
              !episodeBeside(split, spread: spreadContext(fold, hasItem: true)) else { return nil }
        let key = model.tab.listMemoryKey
        return DuoListToggle(hidden: split.primaryHidden, key: key) {
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

    /// v2's floating downloads bar (`DuoDownloadsCapsule`): only where the
    /// tabs' column crosses the fold, which keeps the system's bar away.
    @ViewBuilder
    private var downloadsCapsule: some View {
        if let make = chrome?.downloadsCapsule, let fold = fold.vertical, tabsCrossFold,
           downloadsBar.hasContent, !model.requestScoped, model.tab != .activity, !selectBars.isShowing {
            make(downloadsBar)
                .frame(maxWidth: min(360, fold.lowerBound - 40))
                .padding(.leading, 20)
                .padding(.bottom, 12)
                .transition(.opacity)
        }
    }

    /// The title's column coming in: on the open Duo the right page swings
    /// open from the fold (`DuoPageMotion`, its own animation, as the split
    /// itself doesn't animate there), a slide elsewhere, a plain fade under
    /// Reduce Motion.
    private var detailTransition: AnyTransition {
        if fold.isDuoOpen {
            return DuoPageMotion.transition(motion: !reduceMotion && model.animationsEnabled,
                                            flat: titlePage?.seamHandle != nil)
        }
        if reduceMotion { return .opacity.animation(.easeOut(duration: 0.2)) }
        return .move(edge: .trailing).combined(with: .opacity)
    }

    /// The shell's ground: v2's open title's colours behind the flat open
    /// Duo's split (`TitlePageOverride.shellGround`), else the plain ground.
    @ViewBuilder
    private func shellBackground(_ split: ShellSplit) -> some View {
        if let make = titlePage?.shellGround, split.shown, fold.isDuoOpen, fold.vertical == nil,
           let id = model.presentedItem?.id {
            make(id)
        } else {
            Theme.bg.ignoresSafeArea()
        }
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
        let _ = PerfCount.hit("RootView.body")
        let split = split
        let spread = spreadContext(fold, hasItem: model.rightPageHasItem)
        FoldSplitLayout(axis: split.axis, primary: split.primary, gap: split.gap, primaryHidden: split.primaryHidden,
                        seam: split.seam) {
            // Hidden (the sidebar button), the list keeps its width off screen.
            ShellTabs(fold: fold, splitShown: split.shown, downloadsBar: downloadsBar,
                      downloadsBarAllowed: !tabsCrossFold && !selectBars.isShowing)
                .allowsHitTesting(!split.primaryHidden)
                .accessibilityHidden(split.primaryHidden)
            if split.shown {
                ShellDetailColumn()
                    .modifier(DuoSeamCloseEffect(enabled: titlePage?.seamHandle != nil,
                                                 progress: split.seam?.closeProgress ?? 0))
                    .transition(detailTransition)
            }
        }
        // Gesture 4: swipe in from the content's trailing edge for the page just closed.
        .overlay(alignment: .trailing) {
            if fold.isDuoOpen { DuoReopenEdge() }
        }
        // v2's split handle on the seam (`V2SplitHandle`).
        .overlay(alignment: .topLeading) {
            if let make = titlePage?.seamHandle, let context = seamContext(split) { make(context) }
        }
        .background { shellBackground(split) }
        // Measured without the keyboard: typing in inner landscape must not
        // drop the height under the split rule and fold the title into a sheet
        // (`steadied(after:)`: on the open Duo the keyboard still got through).
        .background {
            Color.clear
                .ignoresSafeArea(.keyboard)
                .onGeometryChange(for: FoldInfo.self) { FoldInfo($0) } action: { measured in
                    let newFold = measured.steadied(after: fold)
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
        // The moving seam is left out: v2's handle animates it itself.
        .animation(reduceMotion || fold.isDuoOpen ? nil : .smooth(duration: 0.3), value: split.atRest)
        // Toasts: above the tab bar when folded; on the trailing column when
        // split, so they never straddle the fold (DC14); on the right page
        // while a Spread's tab spans both pages.
        // v2: the downloads bar floats on the left page where the system's can't show.
        .overlay(alignment: .bottomLeading) { downloadsCapsule }
        .overlay {
            ToastLayer(region: ToastRegion.shell(split, spread: spread, size: fold.size),
                       clearsAbove: split.shown || spread.spans ? nil : toastAnchor.floor, gap: 16)
        }
        .environment(toastAnchor)
        .environment(selectBars)
        .environment(pillSpace)
        .environment(\.spread, spread)
        .environment(\.spreadActive, spread.isActive)
        .environment(\.duoListToggle, listToggle(split))
        .environment(\.titleSpread, titleSpread(split, spread: spread))
        .environment(\.duoOpen, fold.isDuoOpen)
        .environment(seam)
        .environment(\.spreadSpanRequests, spanRequests)
        .environment(\.bookPose, fold.vertical != nil)
        .environment(\.motionEnabled, !reduceMotion && model.animationsEnabled)
        .environment(\.railStyle, model.railStyle)
        .environment(\.railConsolidate, model.railConsolidate)
        .sheet(item: sheetItem, onDismiss: { model.sheetPresence.dismissed() }) { ref in
            // A stack of its own, so Close, Refresh and Open in the web app are
            // system toolbar items over the art (DC10, ruling Q-DC8).
            TitleStack(itemId: ref.id, host: .sheet) { TitlePageHost(store: model.detailStore(for: ref.id)) }
                .onAppear {
                    model.sheetPresence.shown()
                    DeepLinkProbe.log("detail \(ref.id) shown")
                }
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.bg)
        }
        .modifier(ShellPresentations(model: model, reduceMotion: reduceMotion, scenePhase: scenePhase,
                                     duoOpen: fold.isDuoOpen, accountOnPages: fold.isDuoOpen && duoLayout == .spread,
                                     measured: fold.size != .zero))
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
