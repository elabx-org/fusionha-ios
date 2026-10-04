import UIKit
import UserNotifications

extension Notification.Name {
    /// The APNs device token arrived (or changed); `PushRegistration` sends it to the server.
    static let apnsTokenChanged = Notification.Name("fusionha.apnsTokenChanged")
    /// A notification was tapped; `object` is the library item id to open.
    static let openNotificationItem = Notification.Name("fusionha.openNotificationItem")
}

/// Registers for push and hands the APNs device token to `PushRegistration`,
/// which registers it with the fusionha server's APNs channel.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static let deviceTokenKey = "apnsDeviceToken"
    /// Why registration failed (typically a build signed without the push entitlement).
    static let registrationErrorKey = "apnsRegistrationError"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Tokens can change (restore, reinstall, re-sign): re-register every launch
        // once the user has granted permission.
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) else { return }
            DispatchQueue.main.async { application.registerForRemoteNotifications() }
        }
        return true
    }

    static func requestPushAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(hex, forKey: Self.deviceTokenKey)
        UserDefaults.standard.removeObject(forKey: Self.registrationErrorKey)
        NotificationCenter.default.post(name: .apnsTokenChanged, object: hex)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Expected on builds signed without the push entitlement.
        UserDefaults.standard.removeObject(forKey: Self.deviceTokenKey)
        UserDefaults.standard.set(error.localizedDescription, forKey: Self.registrationErrorKey)
        NotificationCenter.default.post(name: .apnsTokenChanged, object: nil)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    /// Tapping a notification opens its title (`item_id`, else the `/library/{id}` url).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        var itemId = (info["item_id"] as? Int) ?? (info["item_id"] as? NSNumber)?.intValue
        if itemId == nil, let url = info["url"] as? String, url.hasPrefix("/library/") {
            itemId = Int(url.dropFirst("/library/".count))
        }
        if let itemId {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .openNotificationItem, object: itemId)
            }
        }
        completionHandler()
    }
}
