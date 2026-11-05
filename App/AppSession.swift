import Foundation
import Observation
import WidgetKit
import FusionhaKit

/// What the whole app shares, once per process: the sign-in, the account,
/// the library, the queue, the shell's badges and settings, the setup
/// progress, and the pollers that keep them fresh (`AppSession+Polling`).
///
/// Every window has its own `AppModel` (its tab, open title, sheets,
/// selection, toasts) over this one session, so v2's windows side by side
/// show the same data without polling twice (`docs/v2.md`, Multiple windows).
/// v1 has a single window: one session, one model, as before.
///
/// The data below is written only by `AppSession` (its extensions live in
/// other files, so the setters can't be `private`); screens read it through
/// the model's get-only forwards (`AppModel+Session`).
@MainActor
@Observable
final class AppSession {
    var credentials: Credentials? = CredentialStore.load()
    var me: Me? = nil { didSet { updatePolling() } }
    /// Bumped by every answered `loadMe`: each window applies the account's
    /// reduced nav when it changes (`AppModel.applyAccountScope`).
    var meLoads = 0

    let shell = ShellState()
    /// The setting-up pill and the posters' setup rings (shared by every tab).
    let setupProgress = SetupProgress()

    // The library list, shared by Library and the top-bar search.
    var library: [MediaItem] = [] {
        didSet {
            var map: [String: Int] = [:]
            for item in library { if let tmdb = item.tmdbId { map[Self.tmdbKey(tmdb, item.kind)] = item.id } }
            libraryIdByTmdb = map
        }
    }
    /// TMDB id → library item id (the web's Discover `idByTmdb`). Discover rows
    /// carry only `in_library`; the server fills `library_item_id` on /search alone.
    @ObservationIgnored private var libraryIdByTmdb: [String: Int] = [:]
    private static func tmdbKey(_ tmdbId: Int, _ kind: MediaKind) -> String { "\(kind == .movie ? "m" : "s")\(tmdbId)" }
    var libraryLoaded = false
    var libraryError: String?
    /// Bumped whenever `library` changes, so screens can rebuild derived lists.
    var libraryVersion = 0

    // Queue state drives the Activity tab, the downloads accessory, the
    // Live Activity and the Downloads widget (AppSession+Queue).
    var queue: [QueueItem] = [] { didSet { queueSlots.update(queue) } }
    /// Per-version views of `queue` for the Library's version chips (`QueueSlots`).
    @ObservationIgnored let queueSlots = QueueSlots()
    var queueTotal = 0
    /// The queue has been seen once (cache or poll): until then counts are unknown, not zero.
    var queueLoaded = false
    /// Downloads held for a manual import (the Activity header caption).
    var queueHeld = 0
    /// fusionha's own downloads are paused (Activity › Pause, 0.4.205).
    var queuePaused = false
    /// The held (manual-import-required) downloads on queue page 1.
    var queueHeldIds: [Int] = []
    var queueError: String?
    @ObservationIgnored var lastQueueIds: [Int] = []

    /// The pollers and the windows holding them (AppSession+Polling).
    @ObservationIgnored var polling = SessionPolling()
    /// The windows, for links that belong to one of them (AppSession+Windows).
    @ObservationIgnored var windows = SessionWindows()
    /// The token whose account was loaded once for the shell (`loadAccountOnce`).
    @ObservationIgnored var bootedToken: String?
    /// `loadAccountOnce` is running (two windows restored at launch run it together).
    @ObservationIgnored private var accountLoading = false
    /// The first library fetch, shared by every screen that waits for it (`loadLibraryIfNeeded`).
    @ObservationIgnored private var initialLibraryLoad: Task<Void, Never>?
    /// A link no window could take yet (`routeLink`); the next window to come forward opens it.
    @ObservationIgnored var pendingLink: URL?

    init() {
        #if DEBUG
        // CI screenshots: point at the mock server (AppModel opens the screen).
        let env = ProcessInfo.processInfo.environment
        if let server = env["FUSIONHA_SCREENSHOT_SERVER"].flatMap(URL.init(string:)) {
            credentials = Credentials(serverURL: server, token: "screenshot", tokenId: nil)
        } else if env["FUSIONHA_SCREENSHOT_LOGIN"] != nil {
            credentials = nil
        }
        #endif
        observePush()
        // Re-save on launch so sign-ins from older builds also land in the
        // keychain record the widgets read, then let the widgets refresh.
        if let credentials, ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_SERVER"] == nil {
            CredentialStore.save(credentials)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    var client: APIClient? {
        credentials?.client()
    }

    // MARK: Access (AppModel+Access reads these through)

    /// Requester accounts get the web's reduced nav.
    var requestScoped: Bool { me?.requestScoped == true }
    var canManageIssues: Bool {
        guard let me else { return false }
        return me.isAdmin || (me.permissions ?? []).contains("issues.manage")
    }
    var canApproveRequests: Bool {
        guard let me else { return false }
        return me.isAdmin || (me.permissions ?? []).contains("requests.approve")
    }

    // MARK: Account and library

    func loadMe() async {
        guard let client else { return }
        if let me = try? await client.me() {
            self.me = me
            meLoads += 1
        }
    }

    /// The shell's first load (account, push device): once per sign-in, not
    /// once per window. Runs again while the account hasn't answered.
    func loadAccountOnce() async {
        guard !accountLoading, let token = credentials?.token, token != bootedToken || me == nil else { return }
        accountLoading = true
        defer { accountLoading = false }
        bootedToken = token
        await loadMe()
        await registerPushDevice()
    }

    /// The library item for a TMDB result: its own id when sent, else the lookup.
    func libraryItemId(for result: MediaSearchResult) -> Int? {
        result.libraryItemId ?? libraryIdByTmdb[Self.tmdbKey(result.tmdbId, result.kind)]
    }

    /// Draws the last library this phone saw, at once, while the server's
    /// answer is on its way (a cold launch otherwise waits for the whole fetch).
    func restoreLibrary() async {
        guard library.isEmpty, let server = credentials?.serverURL else { return }
        let cached = await Task.detached(priority: .userInitiated) { LibraryDiskCache.load(server: server) }.value
        guard library.isEmpty, let cached, !cached.isEmpty else { return }
        library = cached
        libraryVersion += 1
    }

    /// The first load (cached library, then the server's): one fetch however
    /// many screens and windows ask at once. Refreshes after an action call
    /// `loadLibrary` directly, so they never join an older fetch.
    func loadLibraryIfNeeded() async {
        guard !libraryLoaded else { return }
        if let running = initialLibraryLoad {
            await running.value
            return
        }
        let load = Task { @MainActor in
            await self.restoreLibrary()
            await self.loadLibrary()
        }
        initialLibraryLoad = load
        await load.value
        if initialLibraryLoad == load { initialLibraryLoad = nil }
    }

    func loadLibrary() async {
        guard let client else { return }
        do {
            let previousCount = library.count
            let fresh = try await client.libraryWithData()
            library = fresh.items
            libraryVersion += 1
            let server = client.baseURL, raw = fresh.data
            Task.detached(priority: .utility) { LibraryDiskCache.save(raw, server: server) }
            // A new title starts a setup: show the pill now, not at the next calm poll.
            if libraryLoaded, library.count > previousCount, !requestScoped {
                Task { _ = await setupProgress.refresh(client: client) }
            }
            libraryError = nil
        } catch {
            // A fetch cancelled with its view (the sign-in → app hand-over) is
            // not an answer: leave the library unloaded so the next appearance
            // fetches again, instead of an empty library until pull-to-refresh.
            if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled { return }
            libraryError = error.localizedDescription
        }
        libraryLoaded = true
    }

    // MARK: Sign-out and cache

    /// Forgets the sign-in and everything fetched with it. Each window resets
    /// its own screens (`AppModel.resetUI`).
    func signOut() {
        CredentialStore.clear()
        WebSessionStore.clear()
        credentials = nil
        bootedToken = nil
        pendingLink = nil
        initialLibraryLoad = nil
        me = nil
        LibraryDiskCache.clear()
        ResponseDiskCache.clear()
        library = []
        libraryVersion += 1
        libraryLoaded = false
        queue = []
        queueTotal = 0
        queueLoaded = false
        queueHeld = 0
        queueHeldIds = []
        shell.reset()
        LiveActivityController.endAll()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// "Reset cache & reload": drop cached responses and artwork, then refetch.
    func resetCacheAndReload() async {
        URLCache.shared.removeAllCachedResponses()
        ImagePipeline.shared.removeAll()
        ArtBlurCache.shared.removeAll()
        await ArtPaletteExtractor.shared.removeAll()
        LibraryDiskCache.clear()
        ResponseDiskCache.clear()
        libraryLoaded = false
        await loadMe()
        await loadLibrary()
        await refreshShell()
        await refreshQueue()
    }
}
