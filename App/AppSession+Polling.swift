import Foundation
import FusionhaKit

/// The session's pollers and the leases that keep them running. A window
/// holds a lease while its shell is on screen and its scene is active; the
/// queue, shell and setup loops run while any lease is held, once for the
/// whole app. Each activation gets its own token, so a late release from a
/// window that went inactive and came back can't end the newer lease.
struct SessionPolling {
    var leases: Set<UUID> = []
    var queue: Task<Void, Never>?
    var shell: Task<Void, Never>?
    var setups: Task<Void, Never>?
    /// The account each account-bound loop was started for (nil = stopped).
    var shellAccount: Int?
    var setupsAccount: Int?
}

extension AppSession {
    // MARK: Leases

    /// A window became active with its shell on screen: polling runs (or keeps running).
    func acquirePolling(for window: AppModel) -> UUID {
        let token = UUID()
        polling.leases.insert(token)
        windows.becameActive(window)
        // A link that arrived before any window could show it (`routeLink`).
        if let url = pendingLink {
            pendingLink = nil
            window.receiveDeepLink(url)
        }
        updatePolling()
        return token
    }

    func releasePolling(_ token: UUID) {
        polling.leases.remove(token)
        updatePolling()
    }

    /// Starts or stops each loop to match the leases and the account: the
    /// queue while any window is active; the shell badges once the account
    /// is known; the setups for accounts that can add titles. A new account
    /// restarts its loops, as the shell's per-account tasks used to.
    func updatePolling() {
        let active = !polling.leases.isEmpty
        if active, polling.queue == nil {
            polling.queue = loop { await $0.pollQueue() }
        } else if !active, let task = polling.queue {
            task.cancel()
            polling.queue = nil
        }
        let shellAccount = active ? me?.id : nil
        if shellAccount != polling.shellAccount {
            polling.shell?.cancel()
            polling.shell = shellAccount == nil ? nil : loop { await $0.pollShell() }
            polling.shellAccount = shellAccount
        }
        let setupsAccount = active && !requestScoped ? me?.id : nil
        if setupsAccount != polling.setupsAccount {
            polling.setups?.cancel()
            polling.setups = setupsAccount == nil ? nil : loop { await $0.pollSetups() }
            polling.setupsAccount = setupsAccount
        }
    }

    /// One poller, on the main actor like the view tasks it replaces.
    private func loop(_ body: @escaping @MainActor (AppSession) async -> Void) -> Task<Void, Never> {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await body(self)
        }
    }

    // MARK: Shell data (avatar dot, nav badges, rail settings)

    func refreshShell() async {
        guard let client else { return }
        let held = queue.filter { $0.status.lowercased() == "held" }.count
        await shell.refresh(client: client, requestScoped: requestScoped, canApproveRequests: canApproveRequests,
                            canManageIssues: canManageIssues, held: held)
    }

    func pollShell() async {
        while !Task.isCancelled {
            await refreshShell()
            try? await Task.sleep(for: .seconds(30))
        }
    }

    // MARK: Setup progress

    /// Polls `GET /api/v1/library/setups`: every 2s while anything is setting
    /// up, else every 20s. A finished step reloads the library.
    func pollSetups() async {
        while !Task.isCancelled {
            if let client, Date().timeIntervalSince(setupProgress.lastRefresh) >= setupProgress.list.pollInterval {
                if await setupProgress.refresh(client: client) { await loadLibrary() }
            }
            try? await Task.sleep(for: .seconds(1))
        }
    }
}
