import Foundation
import FusionhaKit

/// The window's view of the app-wide `AppSession`: every screen keeps
/// reading `model.library`, `model.queue`, `model.credentials` and the rest,
/// and Observation tracks those reads on the session, so every window
/// updates together while the data is fetched once.
extension AppModel {
    var credentials: Credentials? {
        get { session.credentials }
        set { session.credentials = newValue }
    }
    var me: Me? { session.me }
    var client: APIClient? { session.client }

    var shell: ShellState { session.shell }
    var setupProgress: SetupProgress { session.setupProgress }

    var library: [MediaItem] { session.library }
    var libraryLoaded: Bool { session.libraryLoaded }
    var libraryError: String? { session.libraryError }
    var libraryVersion: Int { session.libraryVersion }

    var queue: [QueueItem] { session.queue }
    var queueSlots: QueueSlots { session.queueSlots }
    var queueTotal: Int { session.queueTotal }
    var queueLoaded: Bool { session.queueLoaded }
    var queueHeld: Int { session.queueHeld }
    var queuePaused: Bool {
        get { session.queuePaused }
        set { session.queuePaused = newValue }
    }
    var queueHeldIds: [Int] { session.queueHeldIds }
    var queueError: String? { session.queueError }

    /// Bumped by every answered account load (`applyAccountScope`).
    var meLoads: Int { session.meLoads }

    func libraryItemId(for result: MediaSearchResult) -> Int? { session.libraryItemId(for: result) }
    func loadMe() async { await session.loadMe() }
    func restoreLibrary() async { await session.restoreLibrary() }
    func loadLibrary() async { await session.loadLibrary() }
    func loadLibraryIfNeeded() async { await session.loadLibraryIfNeeded() }
    func refreshQueue() async { await session.refreshQueue() }
    func refreshShell() async { await session.refreshShell() }
    func registerPushDevice() async { await session.registerPushDevice() }

    /// Requester accounts land on Discover (the web's reduced nav), in every
    /// window, whenever the account answers.
    func applyAccountScope() {
        if requestScoped, ![.discover, .requests, .you, .search].contains(tab) { tab = .discover }
    }

    /// Signs out everywhere; this window resets its screens at once, the
    /// others when they see the sign-in go (`resetUI`).
    func signOut() {
        session.signOut()
        resetUI()
    }

    /// The window's own state back to a fresh shell (after a sign-out).
    func resetUI() {
        searchText = ""
        tab = .library
        allTitles.close()
        selectMode = false
        selection = []
    }

    /// "Reset cache & reload": drop cached responses and artwork, then refetch.
    func resetCacheAndReload() async {
        await session.resetCacheAndReload()
        toast("Cache cleared")
    }

    /// While this window is active with its shell on screen it holds a
    /// polling lease (`AppSession+Polling`); cancelling the task releases it.
    func holdPollingLease() async {
        let token = session.acquirePolling(for: self)
        foregroundLeases += 1
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3600))
        }
        foregroundLeases -= 1
        session.releasePolling(token)
    }
}
