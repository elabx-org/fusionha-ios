import Foundation

// MARK: - Queue clear  (GET /api/v1/activity/idle-summary, fusionha 0.4.156)

/// What Activity shows when nothing is downloading: system status instead of a
/// blank list. Read-only and cheap on the server (it never probes a client or
/// indexer live), so it is safe to poll with the queue.
public struct IdleSummary: Decodable, Sendable, Equatable {
    public struct Counts: Decodable, Sendable, Equatable {
        public let grabbed: Int
        public let imported: Int
        public let failed: Int
    }

    public struct History: Decodable, Sendable, Equatable {
        /// From the viewer's local midnight (`today_start`).
        public let today: Counts
        /// Rolling 7 days.
        public let week: Counts
        public let grabbed24h: Int
    }

    public struct Client: Decodable, Sendable, Equatable, Identifiable {
        public let id: Int
        public let name: String
        public let `protocol`: String
        public let enabled: Bool
    }

    public struct Clients: Decodable, Sendable, Equatable {
        public let total: Int
        public let enabled: Int
        public let items: [Client]
    }

    public struct Indexers: Decodable, Sendable, Equatable {
        public let total: Int
        public let healthy: Int
        public let backoff: Int
        public let off: Int
    }

    public struct Disk: Decodable, Sendable, Equatable {
        public let freeBytes: Int64
        public let totalBytes: Int64
        public let roots: Int
        public let volumes: Int
    }

    public struct Task: Decodable, Sendable, Equatable {
        /// Naive UTC.
        public let nextRun: String
        public let intervalSeconds: Int
        public let lastDuration: Double?
        public let running: Bool
        public var nextRunDate: Date? { ServerTime.parse(nextRun) }
    }

    public struct Tasks: Decodable, Sendable, Equatable {
        public let rss: Task?
        public let search: Task?
        public let upgrade: Task?
    }

    public let history: History
    public let clients: Clients
    public let indexers: Indexers
    public let disk: Disk?
    public let tasks: Tasks

    /// Ready = something can grab (a client on, an indexer healthy) and the
    /// disk isn't nearly full (over 5% free). Anything else reads "Needs a
    /// look", amber, never red (the web's `isReady`).
    public var isReady: Bool {
        let diskOK = disk.map { Double($0.freeBytes) / Double(max(1, $0.totalBytes)) > 0.05 } ?? true
        return clients.enabled > 0 && indexers.healthy > 0 && diskOK
    }

    public var readinessLabel: String { isReady ? "All systems ready" : "Needs a look" }

    /// `900` → "every 15 min", `43200` → "every 12 h".
    public static func everyLabel(seconds: Int) -> String {
        seconds < 3600 ? "every \(Int((Double(seconds) / 60).rounded())) min"
                       : "every \(Int((Double(seconds) / 3600).rounded())) h"
    }

    /// `USENET` → "Usenet".
    public static func protocolLabel(_ value: String) -> String {
        value.prefix(1).uppercased() + value.dropFirst().lowercased()
    }
}

extension APIClient {
    /// Gate: same as `/queue` (management; request-only accounts are excluded).
    public func idleSummary(now: Date = Date(), calendar: Calendar = .current) async throws -> IdleSummary {
        try await get("/api/v1/activity/idle-summary", query: [
            URLQueryItem(name: "today_start", value: ServerTime.localMidnightISO(now: now, calendar: calendar)),
        ])
    }
}
