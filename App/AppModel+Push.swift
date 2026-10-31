import Foundation
import FusionhaKit

extension AppModel {
    // MARK: Native push (APNs)

    /// Registers the APNs token whenever iOS issues one, and opens tapped notifications.
    func observePush() {
        NotificationCenter.default.addObserver(forName: .apnsTokenChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.registerPushDevice() }
        }
        NotificationCenter.default.addObserver(forName: .openNotificationLink, object: nil, queue: .main) { [weak self] note in
            guard let url = note.object as? URL else { return }
            Task { @MainActor in self?.receiveDeepLink(url) }
        }
    }

    /// `POST /api/v1/notifications/apns/devices` for this install, when signed in
    /// (not as the read-only demo, and never against the screenshot mock).
    func registerPushDevice() async {
        guard let client, credentials?.method != .demoCookie,
              ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_SERVER"] == nil else { return }
        if let device = await PushRegistration.register(with: client) {
            UserDefaults.standard.set(device.id, forKey: "apnsDeviceId")
        }
        LiveActivityPushTokens.start(client: client)
    }
}
