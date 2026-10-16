import SwiftUI
import FusionhaKit

/// Everything the Plex server panel reads and does (web `lib/api/plex-server.ts`,
/// `plex-connections.ts` and the panel's `use-*` hooks). Every write ends in
/// `reload()`, the web's one `invalidatePlexState`.
@MainActor
@Observable
final class PlexServerModel {
    enum SyncPhase { case idle, running, ok, failed }
    enum ProbePhase { case testing, tested, error }

    private(set) var server: PlexServerInfo?
    private(set) var libraries: [PlexLibrary]?
    private(set) var preview: PlexAccessPreview?
    private(set) var tierAccess: [UserTierAccess] = []
    private(set) var names: [Int: String] = [:]
    private(set) var loadError: String?

    // Test connection: this session's result, kept only for the URL it tested.
    private(set) var testing = false
    private(set) var testedURL: String?
    private(set) var testResult: PlexServerTestResult?

    // The Server URL probe, revealed one answer at a time.
    private(set) var probe: PlexConnectionsProbe?
    private(set) var probing = false
    private(set) var probeError: Error?
    private(set) var revealed = 0
    private(set) var settled = true
    private var probeGeneration = 0
    /// The picker is showing (a Verify TLS change re-probes at once).
    var pickerOpen = false
    var motionOff = false

    private(set) var savingSetting = false
    private(set) var redetecting = false
    private(set) var syncPhase: SyncPhase = .idle
    private(set) var acking = false
    private(set) var flashKey: String?

    private let app: AppModel

    init(app: AppModel) {
        self.app = app
    }

    private var client: APIClient? { app.client }

    // MARK: Reads

    func reload() async {
        guard let client else { return }
        async let s = client.plexServer()
        async let l = client.plexLibraries()
        async let p = client.plexAccessPreview()
        async let a = client.plexTierAccess()
        async let u = client.userAccounts()
        do {
            server = try await s
            loadError = nil
        } catch is CancellationError {
            return
        } catch {
            if server == nil {
                loadError = ErrorCopy.message(for: error, fallback: "Couldn’t load the Plex server. Only an administrator can manage it.")
            }
        }
        if let v = try? await l { libraries = v } else if libraries == nil { libraries = [] }
        if let v = try? await p { preview = v }
        if let v = try? await a { tierAccess = v }
        if let v = try? await u { names = Dictionary(v.map { ($0.id, $0.displayName) }, uniquingKeysWith: { a, _ in a }) }
    }

    // MARK: Probe

    var probePhase: ProbePhase {
        if probing { return .testing }
        if probeError != nil { return .error }
        if let probe, settled, revealed >= probe.results.count { return .tested }
        return .testing
    }

    /// The answers revealed so far, by URI.
    var probeResults: PlexProbeMap {
        guard let probe, !probing else { return [:] }
        let shown = PlexConnectionLabels.arrivalOrder(probe.results).prefix(revealed)
        return Dictionary(shown.map { ($0.uri, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// Runs the probe once while the picker shows; a finished probe is kept.
    func ensureProbe() async {
        guard probe == nil, probeError == nil, !probing else { return }
        await runProbe()
    }

    func runProbe() async {
        guard let client else { return }
        probeGeneration += 1
        let mine = probeGeneration
        probing = true
        probeError = nil
        revealed = 0
        settled = false
        do {
            let fresh = try await client.probePlexConnections()
            guard mine == probeGeneration else { return }
            probe = fresh
            probing = false
            await reveal(fresh.results.count, generation: mine)
        } catch {
            guard mine == probeGeneration else { return }
            probeError = error
            probing = false
            settled = true
        }
    }

    private func reveal(_ n: Int, generation: Int) async {
        if motionOff || n == 0 {
            revealed = n
            settled = true
            return
        }
        let step = max(0.02, min(0.09, 0.9 / Double(n)))
        for i in 1...n {
            try? await Task.sleep(for: .seconds(step))
            guard generation == probeGeneration else { return }
            revealed = i
        }
        try? await Task.sleep(for: .seconds(0.38))
        if generation == probeGeneration { settled = true }
    }

    /// Verify TLS changes what the probe answers: drop it, re-run if open.
    private func invalidateProbe() {
        probeGeneration += 1
        probe = nil
        probeError = nil
        probing = false
        revealed = 0
        settled = true
        if pickerOpen { Task { await ensureProbe() } }
    }

    // MARK: Settings writes

    /// `PUT /settings` for one Plex key, then the settings store and every Plex read.
    @discardableResult
    func saveSetting(_ key: String, _ value: JSONValue, store: SettingsStore,
                     errorTitle: String) async -> Bool {
        guard let client else { return false }
        savingSetting = true
        defer { savingSetting = false }
        do {
            _ = try await client.json("PUT", "/api/v1/settings", body: .object([key: value]))
            await store.load()
            if key == "plex_server_verify_tls" { invalidateProbe() }
            await reload()
            return true
        } catch {
            app.toast(error.settingsMessage, title: errorTitle, variant: .error)
            return false
        }
    }

    func saveURL(_ url: String, store: SettingsStore) async -> Bool {
        let ok = await saveSetting("plex_server_url", .string(url), store: store, errorTitle: "Could not save the URL")
        if ok {
            if url.isEmpty { app.toast("Server URL removed", variant: .info) } else { app.toast("Plex server URL saved") }
        }
        return ok
    }

    // MARK: Actions

    /// Tests the SAVED url.
    func test(url: String) async {
        guard let client, !testing else { return }
        testing = true
        defer { testing = false }
        do {
            let result = try await client.testPlexServer()
            testedURL = url
            testResult = result
            await reload()
        } catch {
            app.toast(error.settingsMessage, title: "Test failed", variant: .error)
        }
    }

    func setOverride(_ lib: PlexLibrary, _ value: String?) async {
        guard let client else { return }
        do {
            try await client.setPlexLibraryOverride(sectionKey: lib.sectionKey, value: value)
            flash(lib.sectionKey)
            app.toast(PlexLibraryEvidence.overrideToast(lib.title, value), variant: value == "ON" ? .success : .info)
            await reload()
        } catch {
            app.toast(error.settingsMessage, title: "Could not change the library", variant: .error)
        }
    }

    private func flash(_ key: String) {
        flashKey = key
        Task {
            try? await Task.sleep(for: .seconds(0.96))
            if flashKey == key { flashKey = nil }
        }
    }

    /// Re-detect: kicks the job, follows its command, then refreshes.
    func redetect() async {
        guard let client, !redetecting else { return }
        redetecting = true
        defer { redetecting = false }
        do {
            let started = try await client.redetectPlexLibraries()
            app.toast("Re-detecting 4K libraries…", variant: .info)
            if let id = started.commandId { await follow(id) }
            await reload()
        } catch {
            app.toast(error.settingsMessage, title: "Could not start re-detection", variant: .error)
        }
    }

    /// "Sync now": a manual run bypasses the backoff. Reports whether a complete
    /// sync landed (the preview's `last_synced_at` moved).
    func syncNow() async {
        guard let client, syncPhase != .running else { return }
        let before = preview?.lastSyncedAt
        syncPhase = .running
        do {
            let command = try await client.runSystemTask(name: PlexErrorCode.accessSyncTask)
            if command.status == "running" { await follow(command.id) }
            await reload()
            let now = preview?.lastSyncedAt
            syncPhase = (now != nil && now != before) ? .ok : .failed
        } catch {
            syncPhase = .failed
        }
    }

    /// Polls the commands feed until `id` leaves `running` (or ages out).
    private func follow(_ id: String) async {
        guard let client else { return }
        for _ in 0..<300 {
            try? await Task.sleep(for: .seconds(2))
            if Task.isCancelled { return }
            guard let commands = try? await client.systemCommands() else { continue }
            guard let cmd = commands.first(where: { $0.id == id }), cmd.status == "running" else { return }
        }
    }

    func acknowledge(_ on: Bool) async -> Bool {
        guard let client, !acking else { return false }
        acking = true
        defer { acking = false }
        do {
            preview = try await client.acknowledgePlexAccess(on)
            app.toast(on ? "Plex-derived UHD·4K access is on" : "Plex-derived access is off · everyone is unrestricted again",
                      variant: on ? .success : .info)
            await reload()
            return true
        } catch {
            let code = (error as? APIError)?.code
            if on, code == PlexErrorCode.accessNotSynced || code == PlexErrorCode.noUhdLibrary {
                // A race: the refetched preview carries the same answer.
                await reload()
            } else {
                app.toast(error.settingsMessage, title: on ? "Could not turn it on" : "Could not turn it off",
                          variant: .error)
            }
            return false
        }
    }
}
