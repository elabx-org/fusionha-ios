import Foundation
import Observation
import FusionhaKit

/// One window's state: its tab, search, open title, sheets, pending links,
/// selection and toasts. v1 has one; each v2 window has its own (`V2Window`).
/// The data they show is the app-wide `AppSession`, read through
/// AppModel+Session.swift.
@MainActor
@Observable
final class AppModel {
    /// The app-wide data and pollers this window shows (`AppSession`; the
    /// forwards are in AppModel+Session.swift).
    @ObservationIgnored let session: AppSession
    /// Whether this window's title sheet is on screen (`DetailSheetPresence`).
    @ObservationIgnored let sheetPresence = DetailSheetPresence()
    /// Leases this window holds: its scene is active with its shell on
    /// screen (`holdPollingLease`; a count, as a late release can trail a new lease).
    @ObservationIgnored var foregroundLeases = 0
    var inForeground: Bool { foregroundLeases > 0 }
    var tab: AppTab = .library {
        // Opening the Calendar tab, or tapping it again, brings it back to today.
        didSet {
            if tab == .calendar { calendarTodayTick += 1 }
            if tab == .search { searchFocusTick += 1 }
            // Tapping the tab you are on scrolls it back to the top, as on iOS.
            if tab == oldValue { scrollToTopTick += 1 }
            AppStartTab.remember(tab)
        }
    }
    var calendarTodayTick = 0
    /// Opening the Search tab, or tapping it again, puts the cursor in its field.
    var searchFocusTick = 0

    // Shell state shared by the top bar, the + button and every screen.
    var searchText = ""
    var searchScope: SearchScope = .library
    /// The open title. Its store is kept while it stays open (AppModel+Detail.swift).
    var presentedItem: ItemRef? {
        didSet {
            cardFlags.pick(presentedItem?.id)
            detailSlot.keep(only: presentedItem?.id)
            if presentedItem != nil, spreadPreview != nil { spreadPreview = nil }
            if let oldValue, presentedItem == nil { duoGestures.recordClosed(.title(oldValue), tab: tab) }
        }
    }
    /// A Discover or Search preview on the iPhone Duo Spread's right page; one
    /// right page, so opening a title closes it and the reverse (`SpreadPreview`).
    var spreadPreview: PreviewRoute? {
        didSet {
            if spreadPreview != nil, presentedItem != nil { presentedItem = nil }
            if let oldValue, spreadPreview == nil { duoGestures.recordClosed(.preview(oldValue), tab: tab) }
        }
    }
    /// The open Duo's gestures: the page last closed, the Library's order (`DuoGestureMemory`).
    @ObservationIgnored let duoGestures = DuoGestureMemory()
    @ObservationIgnored var detailSlot = RetainedSlot<DetailStore>()
    @ObservationIgnored var detailGate = DetailHostGate()
    /// A `fusionha://` link waiting for the shell (`DeepLink.swift`). Each
    /// applied link bumps `linkCloseTick`, which closes the avatar's sheets
    /// (`avatar`, presented from the shell); `avatarCoverOpen` says one is up.
    var pendingLink: URL?
    var linkCloseTick = 0
    let avatar = AvatarPresentation()
    var avatarCoverOpen: Bool { avatar.isOpen }
    /// A deep link's sub-tab (`fusionha://activity/indexers`, `discover/requests`),
    /// taken by the screen when it shows.
    var pendingActivityTab: ActivityTab?
    /// Held downloads a link asked to open in Manual Import (the Live Activity's Review).
    var pendingRescueIds: [Int]?
    /// A download a link asked the queue to bring forward (`focus`), and whether
    /// to open "Block release group?" on it (`block=1`). Consumed by the row.
    var pendingQueueFocus: (downloadId: Int, block: Bool)?
    /// The same `focus` for the queue tab: scroll to it, flash it, open its group.
    var pendingQueueScroll: Int?
    /// A run a link asked Tasks to open (`activity/tasks?focus={runId}`). Consumed by the tab.
    var pendingTaskFocus: Int?
    /// `activity/history?item_id=`: History scoped to one title.
    var pendingHistoryFilter: HistoryItemFilter?
    var pendingDiscoverTab: DiscoverTab?
    var showingAdd = false
    /// The Account sheet (avatar menu → Account), owned by AccountView.swift.
    var showingAccount = false
    /// Watchlists & lists to open once Account shows (`fusionha://account/lists[/id]`).
    var pendingLists: ListsLink?
    /// A search result to start the Add sheet with.
    var addPrefill: MediaSearchResult?
    /// Discover's session "Add as" provider for the next Add sheet (nil = none).
    var addProviderOverride: String?
    /// The full-screen omni search (top-bar "Everything", or any non-Library tab).
    /// The Search tab's words (Library's "Everything" hands them over).
    var searchQuery = ""
    /// The web hides the top bar and FAB while scrolling down.
    var chromeHidden = false
    /// Bumped by the top-bar logo: the visible tab scrolls to the top.
    var scrollToTopTick = 0
    var detailIntent: DetailIntent?
    /// The tab the next opened detail starts on; the detail reads and clears it.
    var pendingDetailTab: DetailTab?
    var deleteTarget: DeleteTarget?

    // Library select mode + bulk bar.
    var selectMode = false
    var selection: Set<Int> = [] { didSet { cardFlags.select(selection) } }
    /// Per-card views of `presentedItem` and `selection` (`CardFlags`).
    @ObservationIgnored let cardFlags = CardFlags()

    /// App-wide toasts (components/ui/Toast). Call `toast(...)` from any screen.
    private(set) var toasts: [ToastMessage] = []
    /// Their auto-dismiss clocks, paused while a toast is held.
    let toastClock = ToastClock()

    init(session: AppSession) {
        self.session = session
        tab = AppStartTab.launchTab()
        pendingActivityTab = AppStartTab.launchActivityTab()
        #if DEBUG
        // CI screenshots: point at the mock server and open a given screen.
        let env = ProcessInfo.processInfo.environment
        if env["FUSIONHA_SCREENSHOT_SERVER"] != nil {
            // AppSession pointed the sign-in at the mock server.
            switch env["FUSIONHA_SCREENSHOT_TAB"] {
            case "discover": tab = .discover
            case "search": tab = .search
            case "calendar": tab = .calendar
            case "activity": tab = .activity
            case "wanted":
                tab = .activity
                pendingActivityTab = .wanted
            default: tab = .library
            }
            presentedItem = env["FUSIONHA_SCREENSHOT_ITEM"].flatMap(Int.init).map(ItemRef.init(id:))
            showingAdd = env["FUSIONHA_SCREENSHOT_ADD"] != nil
            showingAccount = env["FUSIONHA_SCREENSHOT_ACCOUNT"] != nil
            searchText = env["FUSIONHA_SCREENSHOT_SEARCH"] ?? ""
            if let omni = env["FUSIONHA_SCREENSHOT_OMNI"] {
                searchQuery = omni
                tab = .search
            }
            // Manual import over a held download (`=77`, the mock's Office S06 pack).
            if let rescue = env["FUSIONHA_SCREENSHOT_RESCUE"].flatMap(Int.init) {
                tab = .activity
                pendingRescueIds = [rescue]
            }
            // Scrolls Activity's queue to a download (`=103`, the mock's held Interstellar).
            if let scroll = env["FUSIONHA_SCREENSHOT_QUEUE_SCROLL"].flatMap(Int.init) { pendingQueueScroll = scroll }
            if env["FUSIONHA_SCREENSHOT_SELECT"] != nil {
                selectMode = true
                selection = [1, 3]
            }
            if let toast = env["FUSIONHA_SCREENSHOT_TOAST"] {
                toasts = [ToastMessage(message: toast, duration: 60)]
            }
            if env["FUSIONHA_SCREENSHOT_LIST"] != nil {
                UserDefaults.standard.set("compact", forKey: "fusionha.library.density")
            } else {
                UserDefaults.standard.set("grid", forKey: "fusionha.library.density")
            }
        }
        #endif
        // Observers don't run for the initializer's own assignments.
        cardFlags.pick(presentedItem?.id)
        cardFlags.select(selection)
        session.register(window: self)
    }

    /// The web's `/preview/{kind}/{tmdb_id}`. Until a native Preview screen
    /// exists this opens the Add sheet on that title (Preview's own Add).
    var previewHandler: ((MediaSearchResult) -> Void)?

    // MARK: Toasts

    func toast(_ message: String, title: String? = nil, variant: ToastVariant = .success, duration: Double = 4,
               action: ToastAction? = nil) {
        let item = ToastMessage(message: message, title: title, variant: variant, duration: duration, action: action)
        toasts.append(item)
        if toasts.count > 3 { toasts.removeFirst(toasts.count - 3) }
        Task { [weak self] in
            guard let self else { return }
            await toastClock.run(item.id, duration: duration) { [weak self] in
                self?.toasts.contains { $0.id == item.id } ?? false
            }
            dismissToast(item.id)
        }
    }

    func dismissToast(_ id: UUID) {
        toasts.removeAll { $0.id == id }
    }
}
