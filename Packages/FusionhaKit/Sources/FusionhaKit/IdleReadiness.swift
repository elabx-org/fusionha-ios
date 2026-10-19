import Foundation

// MARK: - Queue clear readiness copy (web `ReadinessTiles.tsx`, `QueueClearHero.tsx`)

extension IdleSummary {
    /// Free over total, 0 when the disk is unreadable.
    public var freeFraction: Double {
        guard let disk else { return 0 }
        return Double(disk.freeBytes) / Double(Swift.max(1, disk.totalBytes))
    }

    /// The free-space tile reads amber under 5 % free.
    public var diskLow: Bool { disk != nil && freeFraction < 0.05 }

    /// Every configured client is enabled (the strip's green dot).
    public var allClientsOn: Bool { clients.total > 0 && clients.enabled == clients.total }

    /// The strip's disclosure: `1 client` / `2 clients`.
    public var clientsToggleLabel: String { clients.total == 1 ? "1 client" : "\(clients.total) clients" }

    /// `5 roots, one volume` (after the tile's `of 931 GB · `).
    public var rootsVolumesText: String? {
        guard let disk else { return nil }
        return "\(disk.roots) root\(disk.roots == 1 ? "" : "s"), "
            + (disk.volumes == 1 ? "one volume" : "\(disk.volumes) volumes")
    }

    /// `0 in backoff · 21 grabs 24h`.
    public var indexersSubText: String { "\(indexers.backoff) in backoff · \(history.grabbed24h) grabs 24h" }

    /// `every 15 min · last took 35s`.
    public var rssSubText: String {
        let rss = tasks.rss
        let every = Self.everyLabel(seconds: rss?.intervalSeconds ?? 900)
        return every + (rss?.lastDuration.map { " · last took \(Int($0.rounded()))s" } ?? "")
    }

    /// `Missing · then upgrades 21:37` (the clock is the caller's local `HH:mm`).
    public func searchSubText(upgradeClock: String?) -> String {
        "Missing" + (tasks.upgrade != nil ? upgradeClock.map { " · then upgrades \($0)" } ?? "" : "")
    }

    /// The RSS / search tiles' text while their run is under way.
    public var rssRunningSub: String { "checking \(indexers.healthy) indexers for new releases" }
    public static let searchRunningSub = "searching for missing episodes and movies"
}
