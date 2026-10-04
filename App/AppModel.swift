import Foundation
import Observation
import UIKit
import WidgetKit
import FusionhaKit

/// The web's mobile bottom-nav destinations (shell/destinations.tsx).
enum AppTab: Hashable {
    case library, discover, calendar, activity, wanted
    /// Requester accounts (REQUESTOR_DESTINATIONS).
    case requests, you
}

enum SearchScope: Hashable {
    case library, everything
}

/// Opens an item's detail sheet from any screen.
struct ItemRef: Identifiable, Hashable {
    let id: Int
}

/// What the item detail should do once it opens, mirroring the web's
/// `/library/{id}?search={tier}` and `?edit=1` deep links. The detail screen
/// reads and clears `AppModel.detailIntent`.
enum DetailIntent: Hashable {
    case interactiveSearch(QualityTier?)
    case edit
}

/// A title waiting for the Delete confirmation (DeleteItemDialog).
struct DeleteTarget: Identifiable, Hashable {
    let id: Int
    let title: String
}

enum PlexSignInError: Error {
    case timedOut
}

@MainActor
@Observable
final class AppModel {
    var credentials: Credentials? = CredentialStore.load()
    var tab: AppTab = .library
    private(set) var me: Me?

    // Shell state shared by the top bar, the + button and every screen.
    var searchText = ""
    var searchScope: SearchScope = .library
    var presentedItem: ItemRef?
    var showingAdd = false
    /// The Account sheet (avatar menu → Account), owned by AccountView.swift.
    var showingAccount = false
    /// A search result to start the Add sheet with.
    var addPrefill: MediaSearchResult?
    /// The full-screen omni search (top-bar "Everything", or any non-Library tab).
    var showingOmni = false
    var omniQuery = ""
    /// The web hides the top bar and FAB while scrolling down.
    var chromeHidden = false
    /// Bumped by the top-bar logo: the visible tab scrolls to the top.
    var scrollToTopTick = 0
    var detailIntent: DetailIntent?
    var deleteTarget: DeleteTarget?

    // Library select mode + bulk bar.
    var selectMode = false
    var selection: Set<Int> = []

    /// App-wide toasts (components/ui/Toast). Call `toast(...)` from any screen.
    private(set) var toasts: [ToastMessage] = []

    // Shell badges and settings.
    private(set) var attentionCount = 0
    private(set) var pendingRequests = 0
    private(set) var commandsActive = false
    private(set) var settings: ShellSettings?
    /// Quality-profile names for the compact list's subline.
    private(set) var profileNames: [Int: String] = [:]

    func profileName(_ id: Int) -> String? { profileNames[id] }
    var railStyle: RailStyle { RailStyle(rawValue: settings?.libraryRailStyle ?? "") ?? .current }
    var railConsolidate: Bool { settings?.libraryRailConsolidate ?? false }
    var animationsEnabled: Bool { settings?.animationsEnabled ?? true }
    var canApproveRequests: Bool {
        guard let me else { return false }
        return me.isAdmin || (me.permissions ?? []).contains("requests.approve")
    }

    /// Requester accounts get the web's reduced nav.
    var requestScoped: Bool { me?.requestScoped == true }

    // The library list, shared by Library and the top-bar search.
    private(set) var library: [MediaItem] = []
    private(set) var libraryLoaded = false
    private(set) var libraryError: String?
    /// Bumped whenever `library` changes, so screens can rebuild derived lists.
    private(set) var libraryVersion = 0

    // Queue state drives the Activity tab, the downloads accessory, the
    // Live Activity and the Downloads widget.
    private(set) var queue: [QueueItem] = []
    private(set) var queueTotal = 0
    /// Downloads held for a manual import (the Activity header caption).
    private(set) var queueHeld = 0
    private(set) var queueError: String?
    private var lastQueueIds: [Int] = []

    init() {
        #if DEBUG
        // CI screenshots: point at the mock server and open a given screen.
        let env = ProcessInfo.processInfo.environment
        if let server = env["FUSIONHA_SCREENSHOT_SERVER"].flatMap(URL.init(string:)) {
            credentials = Credentials(serverURL: server, token: "screenshot", tokenId: nil)
            switch env["FUSIONHA_SCREENSHOT_TAB"] {
            case "discover": tab = .discover
            case "calendar": tab = .calendar
            case "activity": tab = .activity
            case "wanted": tab = .wanted
            default: tab = .library
            }
            presentedItem = env["FUSIONHA_SCREENSHOT_ITEM"].flatMap(Int.init).map(ItemRef.init(id:))
            showingAdd = env["FUSIONHA_SCREENSHOT_ADD"] != nil
            showingAccount = env["FUSIONHA_SCREENSHOT_ACCOUNT"] != nil
            searchText = env["FUSIONHA_SCREENSHOT_SEARCH"] ?? ""
            if let omni = env["FUSIONHA_SCREENSHOT_OMNI"] {
                omniQuery = omni
                showingOmni = true
            }
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
        } else if env["FUSIONHA_SCREENSHOT_LOGIN"] != nil {
            credentials = nil
        }
        #endif
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

    // MARK: Sign-in

    /// Step 1: check the server is a reachable fusionha and see which sign-in
    /// methods it offers (`GET /health`, `GET /api/v1/setup-status`).
    func connect(server: String) async throws -> (URL, SetupStatus) {
        guard let url = APIClient.normalisedServerURL(server) else { throw APIError.invalidServerURL }
        let anonymous = APIClient(baseURL: url, token: nil)
        _ = try await anonymous.health()
        return (url, try await anonymous.setupStatus())
    }

    /// Step 2a: username and password (sets the session cookie).
    func signIn(server url: URL, username: String, password: String) async throws {
        let anonymous = APIClient(baseURL: url, token: nil)
        try await anonymous.login(username: username, password: password)
        try await finishSignIn(with: anonymous)
    }

    /// Step 2b: Plex. Mints a PIN whose `authUrl` the user opens in a browser sheet.
    func startPlexSignIn(server url: URL) async throws -> PlexPin {
        try await APIClient(baseURL: url, token: nil).createPlexPin()
    }

    /// Polls the PIN every 2s, like the web login, until Plex confirms (the server
    /// then sets the session cookie). Cancel the task to stop waiting.
    /// `authorized` runs before the app switches away from the sign-in screen, so
    /// the caller can close the Plex browser sheet while it can still dismiss it.
    func completePlexSignIn(server url: URL, pin: PlexPin, authorized: () async -> Void) async throws {
        let anonymous = APIClient(baseURL: url, token: nil)
        // The web gives up after 10 minutes.
        let deadline = Date().addingTimeInterval(600)
        while true {
            try Task.checkCancellation()
            if try await anonymous.checkPlexPin(id: pin.id) == .signedIn { break }
            if Date() > deadline { throw PlexSignInError.timedOut }
            try await Task.sleep(for: .seconds(2))
        }
        await authorized()
        try await finishSignIn(with: anonymous)
    }

    /// "Explore the demo": `POST /api/v1/demo/login` sets the read-only demo
    /// cookie, which this device then replays on every call.
    func demoSignIn(server url: URL, username: String?, password: String?) async throws {
        let anonymous = APIClient(baseURL: url, token: nil)
        try await anonymous.demoLogin(DemoLoginRequest(username: username, password: password))
        guard let token = anonymous.demoTokenFromCookie() else { throw APIError.http(status: 401, body: "") }
        let creds = Credentials(serverURL: url, token: token, tokenId: nil, method: .demoCookie)
        CredentialStore.save(creds)
        credentials = creds
    }

    /// OIDC providers offered on the login page (older servers have none).
    func signInProviders(server url: URL) async -> [SignInProvider] {
        let list = (try? await APIClient(baseURL: url, token: nil).authProviders()) ?? []
        return list.filter { $0.kind == "oidc" && $0.authorizeUrl != nil }
    }

    /// With a session cookie in place, mint a personal API token for this device so
    /// the widgets can call the API too.
    private func finishSignIn(with anonymous: APIClient) async throws {
        let url = anonymous.baseURL
        let creds: Credentials
        do {
            let mint = try await anonymous.mintToken(name: "fusionha iOS · \(UIDevice.current.name)")
            creds = Credentials(serverURL: url, token: mint.token, tokenId: mint.id)
        } catch APIError.http(403, _) {
            // Accounts without `tokens.manage.self` (e.g. requesters) fall back to the session token.
            guard let session = anonymous.sessionTokenFromCookie() else { throw APIError.http(status: 403, body: "") }
            creds = Credentials(serverURL: url, token: session, tokenId: nil, method: .session)
        }
        CredentialStore.save(creds)
        WebSessionStore.save(anonymous.sessionTokenFromCookie(), server: url) // Settings web panels sign in with it.
        credentials = creds
        WidgetCenter.shared.reloadAllTimelines()
        AppDelegate.requestPushAuthorization()
    }

    func loadMe() async {
        guard let client else { return }
        if let me = try? await client.me() {
            self.me = me
            if me.requestScoped == true, ![.discover, .requests, .you].contains(tab) { tab = .discover }
        }
    }

    func loadLibrary() async {
        guard let client else { return }
        do {
            library = try await client.library()
            libraryVersion += 1
            libraryError = nil
        } catch {
            libraryError = error.localizedDescription
        }
        libraryLoaded = true
    }

    func open(_ itemId: Int) {
        presentedItem = ItemRef(id: itemId)
    }

    /// The web's `/preview/{kind}/{tmdb_id}`. Until a native Preview screen
    /// exists this opens the Add sheet on that title (Preview's own Add).
    var previewHandler: ((MediaSearchResult) -> Void)?

    func openPreview(_ result: MediaSearchResult) {
        if let previewHandler {
            previewHandler(result)
        } else {
            addPrefill = result
            showingAdd = true
        }
    }

    /// Log out: end the server session and revoke this device's token, then
    /// forget the credentials.
    func logOut() async {
        if let client, let creds = credentials {
            try? await client.logout()
            if let tokenId = creds.tokenId { try? await client.revokeToken(id: tokenId) }
        }
        signOut()
    }

    func signOut() {
        CredentialStore.clear()
        WebSessionStore.clear()
        credentials = nil
        me = nil
        library = []
        libraryVersion += 1
        libraryLoaded = false
        searchText = ""
        tab = .library
        queue = []
        queueTotal = 0
        queueHeld = 0
        selectMode = false
        selection = []
        settings = nil
        attentionCount = 0
        pendingRequests = 0
        LiveActivityController.endAll()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Queue polling (no stream on the server, so poll like the web does)

    func pollQueue() async {
        while !Task.isCancelled {
            await refreshQueue()
            let interval: Double = queue.isEmpty ? 6 : 2
            try? await Task.sleep(for: .seconds(interval))
        }
    }

    func refreshQueue() async {
        PerfCount.hit("AppModel.refreshQueue")
        guard let client else { return }
        do {
            let page = try await client.queue()
            // Polled every 2s: assign only what changed, so observers of the
            // total / held count (Activity's header, the tab badge) don't
            // re-render on every tick while progress moves.
            if queue != page.items { queue = page.items }
            if queueTotal != page.total { queueTotal = page.total }
            let held = page.items.filter { $0.status.lowercased() == "held" }.count
            if queueHeld != held { queueHeld = held }
            if queueError != nil { queueError = nil }
            LiveActivityController.sync(with: page.items)
            let ids = page.items.map(\.id)
            if ids != lastQueueIds {
                lastQueueIds = ids
                WidgetCenter.shared.reloadTimelines(ofKind: "Downloads")
            }
        } catch {
            queueError = error.localizedDescription
        }
    }

    // MARK: Toasts

    func toast(_ message: String, title: String? = nil, variant: ToastVariant = .success, duration: Double = 4) {
        let item = ToastMessage(message: message, title: title, variant: variant, duration: duration)
        toasts.append(item)
        if toasts.count > 3 { toasts.removeFirst(toasts.count - 3) }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            self?.dismissToast(item.id)
        }
    }

    func dismissToast(_ id: UUID) {
        toasts.removeAll { $0.id == id }
    }

    // MARK: Shell data (avatar dot, nav badges, rail settings)

    func refreshShell() async {
        guard let client else { return }
        if let value = try? await client.shellSettings() { settings = value }
        if profileNames.isEmpty, let profiles = try? await client.qualityProfiles() {
            profileNames = Dictionary(profiles.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        }
        if !requestScoped {
            async let library = try? client.libraryAttention()
            async let runs = try? client.runAttention()
            async let indexers = try? client.indexersUnavailable()
            let (l, r, i) = await (library, runs, indexers)
            attentionCount = (l?.count ?? 0) + (r?.count ?? 0) + ((i?.count ?? 0) > 0 ? 1 : 0)
            if let commands = try? await client.commands() {
                commandsActive = commands.contains { ["started", "queued", "running"].contains($0.status.lowercased()) }
            }
        }
        if canApproveRequests, let pending = try? await client.requests(status: "pending") {
            pendingRequests = pending.count
        }
    }

    func pollShell() async {
        while !Task.isCancelled {
            await refreshShell()
            try? await Task.sleep(for: .seconds(30))
        }
    }

    /// Admins pick the library's coverage-rail display (`PUT /api/v1/settings`).
    func updateRails(style: RailStyle? = nil, consolidate: Bool? = nil) async {
        guard let client else { return }
        do {
            try await client.updateRailSettings(RailSettingsUpdate(libraryRailStyle: style?.rawValue,
                                                                   libraryRailConsolidate: consolidate))
            settings = try? await client.shellSettings()
        } catch {
            toast("Couldn't save the rail setting", variant: .error)
        }
    }

    /// "Reset cache & reload": drop cached responses and artwork, then refetch.
    func resetCacheAndReload() async {
        URLCache.shared.removeAllCachedResponses()
        ImagePipeline.shared.removeAll()
        libraryLoaded = false
        await loadMe()
        await loadLibrary()
        await refreshShell()
        await refreshQueue()
        toast("Cache cleared")
    }

    // MARK: Title actions (poster kebab, detail, bulk bar)

    func autoSearch(_ id: Int) {
        Task {
            do {
                try await client?.searchItem(id: id)
            } catch {
                toast("Couldn't start the search", variant: .error)
            }
        }
    }

    func interactiveSearch(_ id: Int, tier: QualityTier?) {
        detailIntent = .interactiveSearch(tier)
        open(id)
    }

    func edit(_ id: Int) {
        detailIntent = .edit
        open(id)
    }

    func setMonitored(_ id: Int, title: String, monitored: Bool) {
        Task {
            do {
                try await client?.bulkMonitor(BulkMonitorRequest(itemIds: [id], monitored: monitored))
                toast(monitored ? "Monitoring \(title)" : "Stopped monitoring \(title)")
                await loadLibrary()
            } catch {
                toast("Couldn't update \(title)", variant: .error)
            }
        }
    }

    /// Refresh metadata as a background run, polled every 1.5s like the web.
    func refreshMetadata(_ id: Int, title: String) {
        toast("Refreshing \(title)…")
        Task {
            guard let client else { return }
            do {
                let dispatch = try await client.refreshItem(id: id, metadataOnly: true)
                var state = try await client.run(id: dispatch.runId)
                while state.isRunning {
                    try await Task.sleep(for: .seconds(1.5))
                    state = try await client.run(id: dispatch.runId)
                }
                if state.failed {
                    toast("Couldn't refresh \(title)", variant: .error)
                } else {
                    toast("Refreshed \(title)")
                    await loadLibrary()
                }
            } catch {
                toast("Couldn't refresh \(title)", variant: .error)
            }
        }
    }

    func confirmDelete(_ id: Int, title: String) {
        deleteTarget = DeleteTarget(id: id, title: title)
    }

    func delete(_ target: DeleteTarget, deleteFiles: Bool) async -> Bool {
        guard let client else { return false }
        do {
            try await client.deleteItem(id: target.id, deleteFiles: deleteFiles)
            toast("\(target.title) deleted")
            if presentedItem?.id == target.id { presentedItem = nil }
            selection.remove(target.id)
            await loadLibrary()
            return true
        } catch {
            toast("Couldn't delete \(target.title)", variant: .error)
            return false
        }
    }

    func exitSelectMode() {
        selectMode = false
        selection = []
    }

    /// Runs one bulk call over the selection, then reloads the library.
    func bulk(_ success: String?, _ failure: String, _ call: @escaping (APIClient, [Int]) async throws -> Void) {
        let ids = Array(selection).sorted()
        guard let client, !ids.isEmpty else { return }
        Task {
            do {
                try await call(client, ids)
                if let success { toast(success) }
                await loadLibrary()
            } catch {
                toast(failure, variant: .error)
            }
        }
    }
}
