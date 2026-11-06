import SwiftUI
import FusionhaKit

/// What the S1 home shows beside its rows and in the server card: counts,
/// the server's version, uptime, database, health checks and storage. Read
/// once per Settings visit, every source on its own (a failed one only
/// leaves its value blank). Nothing here is guessed: a value the server
/// didn't send shows nothing.
@MainActor
@Observable
final class V2SettingsSummary {
    private(set) var version: String?
    private(set) var online: Bool?
    private(set) var uptimeSeconds: Int?
    private(set) var backend: String?
    /// Health checks at warning or error level.
    private(set) var warnings: [HealthCheck] = []
    private(set) var roots: [RootFolderInfo]?
    private(set) var clientCount: Int?
    private(set) var indexerCount: Int?
    private(set) var instanceCount: Int?
    private(set) var taskCount: Int?

    func load(_ client: APIClient?) async {
        guard let client else { online = false; return }
        async let health = try? client.health()
        async let about = try? client.systemAbout()
        async let db = try? client.databaseBackend()
        async let roots = try? client.rootFolderDetails()
        async let clients: [DownloadClientInfo]? = try? client.configList(.downloadClients)
        async let indexers: [SearchIndexerInfo]? = try? client.configList(.searchIndexers)
        async let instances = try? client.instances()
        async let tasks = try? client.systemTasks()

        let h = await health
        online = h.map { $0.status == "ok" } ?? false
        version = h?.version.isEmpty == false ? h?.version : nil
        warnings = (h?.checks ?? []).filter { $0.type == "warning" || $0.type == "error" }
        let a = await about
        if version == nil { version = a?.version }
        uptimeSeconds = a?.uptimeSeconds
        backend = await db.map { $0.backend }
        self.roots = await roots
        clientCount = await clients?.count
        indexerCount = await indexers?.filter(\.enabledSearch).count
        instanceCount = await instances?.count
        taskCount = await tasks?.count
    }

    /// "Postgres" / "SQLite" for the wire's backend word.
    var backendLabel: String? {
        guard let backend else { return nil }
        switch backend.lowercased() {
        case "postgres", "postgresql": return "Postgres"
        case "sqlite": return "SQLite"
        default: return backend
        }
    }

    /// "up 23 h" / "up 4 d" / "up 12 min".
    var uptimeLabel: String? {
        guard let s = uptimeSeconds, s > 0 else { return nil }
        if s >= 172_800 { return "up \(s / 86_400) d" }
        if s >= 3_600 { return "up \(s / 3_600) h" }
        return "up \(max(1, s / 60)) min"
    }

    /// The trailing value on a home or sidebar row, when one is known.
    func value(_ id: String) -> String? {
        switch id {
        case "roots": return roots.map { "\($0.count)" }
        case "clients": return clientCount.map(String.init)
        case "indexers": return indexerCount.map(String.init)
        case "instances": return instanceCount.map(String.init)
        case "system": return taskCount.map(String.init)
        case "database": return backendLabel
        case "about": return version
        case "appearance": return PaletteStore.shared.active.name
        default:
            if let children = V2SettingsNav.groups[id] { return "\(children.count) pages" }
            return nil
        }
    }
}
