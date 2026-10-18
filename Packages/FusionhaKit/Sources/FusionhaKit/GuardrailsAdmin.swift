import Foundation

// MARK: - Guardrails (Settings › Requests, phase 7 A9)

/// `GET /audit/autofix-stats` (admin): automatic fixes inside the window and the paused slots.
public struct AutofixStats: Decodable, Sendable {
    public struct Paused: Decodable, Sendable, Identifiable {
        public let reportId: Int
        public let issueId: Int
        public let title: String?
        public let season: Int?
        public let episode: Int?
        public let pausedAt: String?
        public let tier: QualityTier?
        public let edition: String?
        public let failures: Int
        public let windowDays: Int
        public var id: Int { reportId }

        /// "Andor · S02E04 · UHD·4K".
        public var line: String {
            var parts = [title ?? "Unknown title"]
            if let season, let episode { parts.append(String(format: "S%02dE%02d", season, episode)) }
            if let tier { parts.append(VersionLabel.text(tier: tier, edition: edition, multipleEditions: false) ?? tier.word) }
            return parts.joined(separator: " · ")
        }

        public var failuresLine: String {
            "\(failures) failed \(failures == 1 ? "fix" : "fixes") in \(windowDays) \(windowDays == 1 ? "day" : "days") · current copy kept"
        }
    }

    public let days: Int
    public let attempts: Int
    public let fixed: Int
    public let failed: Int
    public let waiting: Int
    public let successRate: Double?
    public let paused: [Paused]
}

/// The four Auto-fix limits, bounds mirroring the server's validation.
public struct GuardrailLimit: Sendable, Identifiable {
    public let key: String
    public let title: String
    public let sub: String
    public let range: ClosedRange<Int>
    public let fallback: Int
    public let unit: (Int) -> String
    public var id: String { key }

    public static let all: [GuardrailLimit] = [
        .init(key: "autofix_max_failures", title: "Failed fixes before pausing",
              sub: "Per episode or movie version, inside the window below. Reopens count too.", range: 1...10, fallback: 2, unit: { "\($0)" }),
        .init(key: "autofix_failure_window_days", title: "Pause window",
              sub: "How far back a failed fix still counts towards a pause.", range: 1...90, fallback: 7, unit: days),
        .init(key: "issue_reopen_window_days", title: "Reopen automatically for",
              sub: "A resolved report reopens if the same file is found dead again.", range: 1...365, fallback: 30, unit: days),
        .init(key: "selfservice_replace_daily_limit", title: "Language replacements per person",
              sub: "Each day. Searches and Plex rescans have their own limit.", range: 0...50, fallback: 3, unit: { $0 == 0 ? "Off" : "\($0) / day" }),
    ]

    private static func days(_ n: Int) -> String { "\(n) \(n == 1 ? "day" : "days")" }
}

extension APIClient {
    public func autofixStats(days: Int = 30) async throws -> AutofixStats {
        try await get("/api/v1/audit/autofix-stats", query: [URLQueryItem(name: "days", value: String(days))])
    }
}
