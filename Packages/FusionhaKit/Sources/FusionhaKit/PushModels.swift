import Foundation

// MARK: Native iOS push (APNs) — `/api/v1/notifications/apns/*`

/// Whether the server can deliver native iOS push (`GET …/apns/status`).
public struct ApnsStatus: Decodable, Sendable, Hashable {
    public let configured: Bool
    public let enabled: Bool
    public let topic: String
    public let environment: String
    public let missing: [String]
    /// A human sentence when push can't be delivered (no key, or turned off).
    public let message: String?

    public init(configured: Bool, enabled: Bool, topic: String, environment: String,
                missing: [String], message: String?) {
        self.configured = configured
        self.enabled = enabled
        self.topic = topic
        self.environment = environment
        self.missing = missing
        self.message = message
    }
}

/// The APNs channel config (admin). The `.p8` key itself is write-only.
public struct ApnsSettings: Decodable, Sendable, Hashable {
    public let enabled: Bool
    public let configured: Bool
    public let keyId: String
    public let teamId: String
    public let topic: String
    public let environment: String
    public let authKeySet: Bool
}

/// One registered iOS app install.
public struct ApnsDevice: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let deviceToken: String
    public let environment: String
    public let deviceName: String?
    public let appVersion: String?
    public let createdAt: String?
    public let lastSeenAt: String?
    public let lastSuccessAt: String?
    public let failureCount: Int?
    public let lastError: String?
    public let disabled: Bool?
}

/// `POST …/apns/devices` body.
public struct ApnsDeviceRegistration: Encodable, Sendable, Hashable {
    public let deviceToken: String
    /// `sandbox` (development-signed builds) or `production`.
    public let environment: String
    public let deviceName: String?
    public let appVersion: String?

    public init(deviceToken: String, environment: String, deviceName: String?, appVersion: String?) {
        self.deviceToken = deviceToken
        self.environment = environment
        self.deviceName = deviceName
        self.appVersion = appVersion
    }
}

public enum ApnsEnvironment {
    /// The gateway a build talks to, from its provisioning profile's
    /// `aps-environment` entitlement (`development` → sandbox). A missing profile
    /// (App Store) means production; an unreadable one falls back to sandbox. The
    /// server retries the other gateway on `BadDeviceToken` anyway.
    public static func fromProvisioningProfile(_ data: Data?) -> String {
        guard let data else { return "production" }
        let text = String(decoding: data, as: UTF8.self)
        guard let start = text.range(of: "<?xml"), let end = text.range(of: "</plist>"),
              start.lowerBound < end.upperBound,
              let plistData = String(text[start.lowerBound..<end.upperBound]).data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let aps = entitlements["aps-environment"] as? String
        else { return "sandbox" }
        return aps == "production" ? "production" : "sandbox"
    }
}
