import Foundation

/// The shared locked-mode save path (web `secrets-locked-bus.ts` +
/// `SecretsLockedToaster`): any write the server refuses with
/// `409 secrets_locked` is reported once here by `APIClient`, whatever screen
/// made it, and the shell turns it into one toast linking to Settings › Security.
public enum SecretsLockedBus {
    /// Posted (on any thread) for each refused write.
    public static let notification = Notification.Name("org.elabx.fusionha.secretsLocked")
    public static let title = "Secrets are locked"
    public static let message = SecretsErrorCopy.fixed["secrets_locked"] ?? SecretsErrorCopy.generic
    public static let actionLabel = "Open Settings → Security"
    /// The Settings slug the toast's action opens.
    public static let securityPanel = "security"
    /// A burst of refused saves (one tap, several writes) shows one toast.
    public static let quiet: TimeInterval = 4
    /// The toast stays up longer than a plain one (web 10 s).
    public static let duration: Double = 10

    /// A write (not a read) refused with `409 secrets_locked`.
    public static func isLocked(method: String?, error: APIError) -> Bool {
        guard (method ?? "GET").uppercased() != "GET", case .http(409, _) = error else { return false }
        return error.code == "secrets_locked"
    }

    static func report(method: String?, error: APIError) {
        guard isLocked(method: method, error: error) else { return }
        NotificationCenter.default.post(name: notification, object: nil)
    }

    /// The toaster's gate: one toast per quiet window, none on the Security
    /// panel itself (it explains the lock in place).
    public struct Gate: Sendable {
        public private(set) var last: Date?

        public init() {}

        public mutating func admit(at now: Date, onSecurityPanel: Bool) -> Bool {
            if onSecurityPanel { return false }
            if let last, now.timeIntervalSince(last) < SecretsLockedBus.quiet { return false }
            last = now
            return true
        }
    }
}

/// A toast's auto-dismiss clock (web `ToastCard`): it only runs while the
/// toast isn't held (pressed, or focused by VoiceOver), so the timer bar and
/// the dismissal stay in step.
public struct ToastCountdown: Sendable, Equatable {
    /// How often the clock advances, in seconds.
    public static let tick: Double = 0.25

    public let duration: Double
    public private(set) var elapsed: Double = 0

    public init(duration: Double) { self.duration = max(0, duration) }

    public mutating func advance(_ seconds: Double, held: Bool) {
        guard !held else { return }
        elapsed = min(duration, elapsed + max(0, seconds))
    }

    public var expired: Bool { elapsed >= duration }

    /// What's left, 1 → 0 (the timer bar's width).
    public var fraction: Double { duration > 0 ? 1 - elapsed / duration : 0 }
}
