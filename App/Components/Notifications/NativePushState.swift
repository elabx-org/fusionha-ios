import SwiftUI
import UIKit
import UserNotifications
import FusionhaKit

/// The "This device" card's state (web `ThisDevice` → `DeviceState`), in its
/// native form: this install's APNs registration rather than a browser
/// subscription.
enum NativePushStatus {
    case loading, serverNotConfigured(String), serverOff(String), denied, notAsked
    case noEntitlement(String), registering, enabled(ApnsDevice)
}

/// This install's native push (APNs) state plus this user's other iOS devices
/// (web `useThisDevice`, one source of truth). Shared by Settings ›
/// Notifications and the requester's Account.
@MainActor
@Observable
final class NativePushState {
    private(set) var status: ApnsStatus?
    private(set) var devices: [ApnsDevice] = []
    private(set) var authStatus: UNAuthorizationStatus?
    private(set) var testing = false
    private(set) var registering = false
    private(set) var testResult: ConnectionTestResult?

    private var deviceToken: String? { PushRegistration.deviceToken }

    /// This install's row on the server, matched by APNs token.
    var thisDevice: ApnsDevice? {
        guard let token = deviceToken else { return nil }
        return devices.first { $0.deviceToken == token }
    }

    var otherDevices: [ApnsDevice] { devices.filter { $0.deviceToken != deviceToken } }

    var state: NativePushStatus {
        guard let status, let authStatus else { return .loading }
        if !status.configured {
            return .serverNotConfigured(status.message
                ?? "The server has no APNs key configured, so it can't send push to this app yet.")
        }
        if !status.enabled { return .serverOff(status.message ?? "iOS push is turned off on the server.") }
        switch authStatus {
        case .denied: return .denied
        case .notDetermined: return .notAsked
        default: break
        }
        if let device = thisDevice { return .enabled(device) }
        if deviceToken == nil, let error = PushRegistration.registrationError { return .noEntitlement(error) }
        return .registering
    }

    func load(_ client: APIClient?) async {
        guard let client else { return }
        do {
            status = try await client.apnsStatus()
        } catch APIError.http(404, _) {
            status = ApnsStatus(configured: false, enabled: false, topic: "", environment: "", missing: [],
                                message: "This fusionha server doesn't support native iOS push yet. Update it.")
        } catch {
            status = ApnsStatus(configured: false, enabled: false, topic: "", environment: "", missing: [],
                                message: "Couldn't check the server's push setup (\(error.settingsMessage)).")
        }
        devices = (try? await client.apnsDevices()) ?? []
        authStatus = await PushRegistration.authorizationStatus()
    }

    /// Sends a test to this device; returns the message and whether it landed.
    func runTest(_ client: APIClient?) async -> (message: String, ok: Bool)? {
        guard let client else { return nil }
        testing = true
        testResult = nil
        let outcome: (String, Bool)
        do {
            let r = try await client.testApns(deviceId: thisDevice?.id)
            let failure = r.devices?.first { !$0.ok }?.detail
            let message = r.sent == 0
                ? "This device isn't registered yet."
                : r.delivered > 0 ? "Sent. Check your notifications" : (failure ?? "Not delivered")
            outcome = (message, r.delivered > 0)
        } catch {
            outcome = (error.settingsMessage, false)
        }
        testResult = ConnectionTestResult(ok: outcome.1, message: outcome.0)
        testing = false
        await load(client)
        return outcome
    }

    /// Asks iOS for permission, then for a token (AppModel registers it).
    func enable() async {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        if granted { UIApplication.shared.registerForRemoteNotifications() }
        authStatus = await PushRegistration.authorizationStatus()
    }

    /// Re-sends this device's token; false when the server refused it.
    func register(_ client: APIClient?) async -> Bool {
        guard let client else { return false }
        registering = true
        var ok = true
        if PushRegistration.deviceToken == nil {
            UIApplication.shared.registerForRemoteNotifications()
        } else if await PushRegistration.register(with: client) == nil {
            ok = false
        }
        registering = false
        await load(client)
        return ok
    }

    func remove(_ device: ApnsDevice, client: APIClient?) async throws {
        guard let client else { return }
        try await client.deleteApnsDevice(id: device.id)
        devices.removeAll { $0.id == device.id }
    }

    /// Refreshes the server's status after an admin changed the APNs settings.
    func refreshStatus(_ client: APIClient?) async {
        guard let client else { return }
        if let fresh = try? await client.apnsStatus() { status = fresh }
    }

    static func openSystemSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
