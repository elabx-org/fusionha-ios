import ActivityKit
import Foundation
import FusionhaKit

/// Hands the Live Activity's push tokens to fusionha (0.4.205) so the server
/// can start and update the activity while the app is closed: the
/// push-to-start token (`kind: start`) and each activity's own token
/// (`kind: update`), with Account › Live Activity's choices as `prefs`. The
/// server needs this device's APNs registration id, so it registers that
/// first. Without APNs on the server the calls fail quietly and the app keeps
/// updating the activity itself while it runs.
@MainActor
enum LiveActivityPushTokens {
    private static var started = false
    private static var watched: Set<String> = []
    /// The last registration answer, for Account › Live Activity.
    private(set) static var lastStatus: String?

    /// Starts watching tokens; call once signed in.
    static func start(client: APIClient?) {
        guard !started, let client else { return }
        started = true
        self.client = client
        Task {
            for await data in Activity<DownloadsActivityAttributes>.pushToStartTokenUpdates {
                await register(client: client, kind: "start", token: data, activityId: nil)
            }
        }
        Task {
            for activity in Activity<DownloadsActivityAttributes>.activities { watch(activity, client: client) }
            for await activity in Activity<DownloadsActivityAttributes>.activityUpdates { watch(activity, client: client) }
        }
    }

    /// The tokens seen this launch, so a change in Account › Live Activity
    /// can re-send them with the new prefs.
    private static var known: [String: (kind: String, token: Data, activityId: String?)] = [:]
    private static var client: APIClient?

    /// Re-sends every known token with the current prefs.
    static func prefsChanged() {
        guard let client else { return }
        for entry in known.values {
            Task { await register(client: client, kind: entry.kind, token: entry.token, activityId: entry.activityId) }
        }
    }

    private static func watch(_ activity: Activity<DownloadsActivityAttributes>, client: APIClient) {
        guard !watched.contains(activity.id) else { return }
        watched.insert(activity.id)
        let id = activity.id
        Task {
            for await data in activity.pushTokenUpdates {
                await register(client: client, kind: "update", token: data, activityId: id)
            }
        }
        Task {
            for await state in activity.activityStateUpdates where state == .ended || state == .dismissed {
                try? await client.deleteLiveActivityToken(activityId: id)
                watched.remove(id)
                known[id] = nil
                break
            }
        }
    }

    private static func register(client: APIClient, kind: String, token data: Data, activityId: String?) async {
        known[activityId ?? "start"] = (kind, data, activityId)
        let token = data.map { String(format: "%02x", $0) }.joined()
        guard let deviceId = await deviceId(client) else {
            lastStatus = "Not registered: this iPhone has no push registration on the server yet."
            return
        }
        do {
            let saved = try await client.registerLiveActivityToken(deviceId: deviceId, kind: kind, token: token,
                                                                    activityId: activityId, prefs: prefs)
            lastStatus = "Registered \(kind) token" + (saved.lastError.map { " · last error: \($0)" } ?? "")
        } catch {
            lastStatus = "\(kind) token: " + ErrorCopy.message(for: error, fallback: "the server didn't take it")
        }
    }

    /// This device's APNs registration id (an upsert, so it is always current).
    private static func deviceId(_ client: APIClient) async -> Int? {
        if let cached = UserDefaults.standard.object(forKey: "apnsDeviceId") as? Int { return cached }
        guard let device = await PushRegistration.register(with: client) else { return nil }
        UserDefaults.standard.set(device.id, forKey: "apnsDeviceId")
        return device.id
    }

    /// Account › Live Activity's choices, in the server's keys.
    static var prefs: [String: SettingsJSON] {
        let d = UserDefaults.standard
        func flag(_ key: String) -> SettingsJSON { .bool(d.object(forKey: key) as? Bool ?? true) }
        return [
            "new_grabs": flag(LiveActivityPrefs.newGrabsKey), "upgrades": flag(LiveActivityPrefs.upgradesKey),
            "regrabs": flag(LiveActivityPrefs.regrabsKey), "hd": flag(LiveActivityPrefs.hdKey),
            "uhd": flag(LiveActivityPrefs.uhdKey), "waiting_on_you": flag(LiveActivityPrefs.waitingKey),
            "linger_minutes": .int(LiveActivityPrefs.lingerMinutes),
        ]
    }
}
