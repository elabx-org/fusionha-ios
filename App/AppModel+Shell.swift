import Foundation
import FusionhaKit

extension AppModel {
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

    /// Admins pick the library's coverage-rail display (`PUT /api/v1/settings`).
    func updateRails(style: RailStyle? = nil, consolidate: Bool? = nil) async {
        guard let client else { return }
        do {
            try await client.updateRailSettings(RailSettingsUpdate(libraryRailStyle: style?.rawValue,
                                                                   libraryRailConsolidate: consolidate))
            await shell.reloadSettings(client: client)
        } catch {
            toast("Couldn't save the rail setting", variant: .error)
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

    /// The Library scroll hides the chrome scrolling down and shows it
    /// scrolling up or near the top (`offset` from the top of the content).
    func updateChrome(old: CGFloat, new: CGFloat) {
        let delta = new - old
        if new <= 90 {
            if chromeHidden { chromeHidden = false }
        } else if delta > 4 {
            if !chromeHidden { chromeHidden = true }
        } else if delta < -4 {
            if chromeHidden { chromeHidden = false }
        }
    }
}
