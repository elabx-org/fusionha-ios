import Foundation
import FusionhaKit

/// Whether pushes the server sends can reach this install. The server sends
/// every push under one APNs topic (`ApnsStatus.topic`, a bundle id), and APNs
/// rejects a token from any other app. v1 always registers, as it always has.
/// Any other identity (v2 side by side, `org.elabx.fusionha.v2`) registers only
/// once the server's topic is its own bundle id. Nothing here names an id: when
/// v2 takes over v1's ids (docs/v2.md, Cutover) it is v1 to this check.
enum PushAvailability {
    /// The server's topic, last read from `/notifications/apns/status`.
    static let serverTopicKey = "apnsServerTopic"

    static var bundleId: String { Bundle.main.bundleIdentifier ?? "" }

    /// True when a push under `topic` reaches this app.
    static func accepts(topic: String) -> Bool {
        if AppIdentity.current.isV1 { return true }
        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed == bundleId
    }

    /// From the last topic seen; false for a non-v1 app that hasn't asked yet,
    /// so it never prompts for notifications that can't arrive.
    static var canPushHere: Bool {
        if AppIdentity.current.isV1 { return true }
        return accepts(topic: UserDefaults.standard.string(forKey: serverTopicKey) ?? "")
    }

    static func remember(_ status: ApnsStatus) {
        UserDefaults.standard.set(status.topic, forKey: serverTopicKey)
    }

    /// Reads the server's topic (non-v1 only; v1 needs no answer) and returns
    /// whether this app can get its pushes.
    @discardableResult
    static func refresh(with client: APIClient) async -> Bool {
        if AppIdentity.current.isV1 { return true }
        if let status = try? await client.apnsStatus() { remember(status) }
        return canPushHere
    }
}
