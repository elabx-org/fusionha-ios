import Foundation

// fusionha 0.4.205: Live Activity pushes and queue pause / resume.

/// `POST /queue/pause` / `/queue/resume`: the state and each client's answer.
public struct QueuePauseResult: Decodable, Sendable, Hashable {
    public struct Client: Decodable, Sendable, Hashable {
        public let clientId: Int
        public let name: String
        public let `protocol`: String
        public let ok: Bool
        public let detail: String?
    }

    public let paused: Bool
    public let pausedAt: String?
    public let clients: [Client]

    /// "Paused 2 clients" / "1 couldn't pause: client does not support pausing".
    public var summary: String {
        let failed = clients.filter { !$0.ok }
        let verb = paused ? "Paused" : "Resumed"
        if clients.isEmpty { return "\(verb) the queue." }
        if failed.isEmpty { return "\(verb) \(clients.count) download client\(clients.count == 1 ? "" : "s")." }
        let names = failed.map { "\($0.name): \($0.detail ?? "no answer")" }.joined(separator: "; ")
        return "\(verb) \(clients.count - failed.count) of \(clients.count). \(names)"
    }
}

/// One registered Live Activity push token (`LiveActivityTokenRead`).
public struct LiveActivityToken: Decodable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let deviceId: Int
    public let kind: String
    public let activityId: String?
    public let lastSentAt: String?
    public let lastEvent: String?
    public let lastPriority: Int?
    public let lastError: String?
    public let endedAt: String?
}

extension APIClient {
    public func pauseQueue() async throws -> QueuePauseResult {
        try await sendJSON("POST", "/api/v1/queue/pause")
    }

    public func resumeQueue() async throws -> QueuePauseResult {
        try await sendJSON("POST", "/api/v1/queue/resume")
    }

    /// Registers a push-to-start (`start`) or per-activity (`update`) token.
    /// `prefs` mirrors Account › Live Activity so the server pushes what the app would show.
    @discardableResult
    public func registerLiveActivityToken(deviceId: Int, kind: String, token: String, activityId: String?,
                                          prefs: [String: SettingsJSON]) async throws -> LiveActivityToken {
        var body: [String: SettingsJSON] = [
            "device_id": .int(deviceId), "kind": .string(kind), "token": .string(token), "prefs": .object(prefs),
        ]
        if let activityId { body["activity_id"] = .string(activityId) }
        return try await sendJSON("POST", "/api/v1/notifications/apns/live-activity", .object(body))
    }

    public func liveActivityTokens() async throws -> [LiveActivityToken] {
        try await get("/api/v1/notifications/apns/live-activity")
    }

    public func deleteLiveActivityToken(activityId: String) async throws {
        try await sendJSON("DELETE", "/api/v1/notifications/apns/live-activity/\(activityId)")
    }
}
