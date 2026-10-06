import Foundation
import FusionhaKit

/// The shell's badges and settings (avatar dot, nav badges, rail settings),
/// polled every 30s. Each value is assigned only when it changed: an
/// `@Observable` property notifies on every assignment, equal or not, so the
/// old unconditional writes re-rendered everything that reads `settings`
/// (the root view's environment, every poster rail) on each poll.
@MainActor
@Observable
final class ShellState {
    private(set) var attentionCount = 0
    private(set) var pendingRequests = 0
    private(set) var commandsActive = false
    private(set) var settings: ShellSettings?
    /// Quality-profile names for the compact list's subline.
    private(set) var profileNames: [Int: String] = [:]

    func refresh(client: APIClient, requestScoped: Bool, canApproveRequests: Bool) async {
        if let value = try? await client.shellSettings() { set(settings: value) }
        if profileNames.isEmpty, let profiles = try? await client.qualityProfiles() {
            profileNames = Dictionary(profiles.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        }
        if !requestScoped {
            async let library = try? client.libraryAttention()
            async let runs = try? client.runAttention()
            async let indexers = try? client.indexersUnavailable()
            let (l, r, i) = await (library, runs, indexers)
            let count = (l?.count ?? 0) + (r?.count ?? 0) + ((i?.count ?? 0) > 0 ? 1 : 0)
            if attentionCount != count { attentionCount = count }
            if let commands = try? await client.commands() {
                let active = commands.contains { ["started", "queued", "running"].contains($0.status.lowercased()) }
                if commandsActive != active { commandsActive = active }
            }
        }
        if canApproveRequests, let pending = try? await client.requests(status: "pending"),
           pendingRequests != pending.count {
            pendingRequests = pending.count
        }
    }

    /// Re-reads the settings after an admin change.
    func reloadSettings(client: APIClient) async {
        set(settings: try? await client.shellSettings())
    }

    /// Signed out: back to the defaults.
    func reset() {
        settings = nil
        attentionCount = 0
        pendingRequests = 0
    }

    private func set(settings value: ShellSettings?) {
        if settings != value { settings = value }
    }
}
