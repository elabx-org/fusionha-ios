import Foundation
import UIKit
import UserNotifications
import FusionhaKit

/// This install's native push registration with the fusionha server
/// (`/api/v1/notifications/apns/devices`): register after sign-in and whenever
/// the APNs token changes, unregister on sign-out.
enum PushRegistration {
    /// The hex APNs device token, once iOS has issued one.
    static var deviceToken: String? {
        #if DEBUG
        // CI screenshots: pretend iOS issued this token (the simulator gets none).
        if let token = screenshotToken { return token }
        #endif
        return UserDefaults.standard.string(forKey: AppDelegate.deviceTokenKey)
    }

    #if DEBUG
    static var screenshotToken: String? {
        ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_PUSH_TOKEN"]
    }
    #endif

    /// Why iOS refused a token (e.g. the build lacks the push entitlement).
    static var registrationError: String? {
        UserDefaults.standard.string(forKey: AppDelegate.registrationErrorKey)
    }

    /// `sandbox` for development-signed builds, from the embedded provisioning
    /// profile's `aps-environment`; production when there is no profile.
    static let environment: String = {
        #if targetEnvironment(simulator)
        return "sandbox"
        #else
        let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision")
        return ApnsEnvironment.fromProvisioningProfile(url.flatMap { try? Data(contentsOf: $0) })
        #endif
    }()

    static var appVersion: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    /// Sends this device's token to the server (an upsert; also a liveness ping).
    @discardableResult
    static func register(with client: APIClient) async -> ApnsDevice? {
        guard let token = deviceToken else { return nil }
        let name = await MainActor.run { UIDevice.current.name }
        let body = ApnsDeviceRegistration(deviceToken: token, environment: environment,
                                          deviceName: name, appVersion: appVersion)
        return try? await client.registerApnsDevice(body)
    }

    /// Removes this device from the server, before the credentials are dropped.
    static func unregister(with client: APIClient) async {
        guard let token = deviceToken else { return }
        try? await client.unregisterApnsDevice(token: token)
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        #if DEBUG
        if screenshotToken != nil { return .authorized }
        #endif
        return await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}
