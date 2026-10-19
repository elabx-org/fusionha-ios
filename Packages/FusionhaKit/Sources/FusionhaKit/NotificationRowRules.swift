import Foundation

/// Settings › Notifications row rules (web `admin-delivery-rows.ts`,
/// `useNotificationRows`, `AdminDeliveryCard` and `DigestTimeInput`).
public enum NotificationRowRules {
    /// The admin delivery card's kinds, in display order (`ADMIN_DELIVERY_ORDER`).
    public static let adminDeliveryOrder = ["issue_auto_fixed", "self_service_action", "issue_needs_you"]

    /// The digest time the web shows when the server has none.
    public static let defaultDigestTime = "18:00"

    /// Rows for the admin delivery card: the digestible admin kinds, not
    /// retired, in `adminDeliveryOrder` (unknown kinds last, stable).
    public static func adminDelivery(_ rows: [NotificationPreferenceItem]) -> [NotificationPreferenceItem] {
        func rank(_ kind: String) -> Int { adminDeliveryOrder.firstIndex(of: kind) ?? adminDeliveryOrder.count }
        return rows.enumerated()
            .filter { isAdminDelivery($0.element) }
            .sorted { lhs, rhs in
                let l = rank(lhs.element.eventKind), r = rank(rhs.element.eventKind)
                return l == r ? lhs.offset < rhs.offset : l < r
            }
            .map(\.element)
    }

    /// Everything else, in the server's order (the Events switches).
    public static func events(_ rows: [NotificationPreferenceItem]) -> [NotificationPreferenceItem] {
        rows.filter { !isAdminDelivery($0) }
    }

    static func isAdminDelivery(_ row: NotificationPreferenceItem) -> Bool {
        row.audience == "admin" && row.digestAllowed == true && row.retired != true
    }

    /// A row's current delivery: the server's, else derived from the switch.
    public static func delivery(_ row: NotificationPreferenceItem) -> String {
        row.delivery ?? (row.enabled ? "IMMEDIATE" : "OFF")
    }

    /// "Default: …" copy (`DEFAULT_LABEL`); nil when the server sends none.
    public static func defaultLabel(_ delivery: String?) -> String? {
        switch delivery {
        case "IMMEDIATE": return "Default: immediate"
        case "DIGEST": return "Default: daily digest"
        case "OFF": return "Default: off"
        default: return nil
        }
    }

    /// `HH:MM` → hour and minute; nil when malformed or out of range.
    public static func parseTime(_ text: String?) -> (hour: Int, minute: Int)? {
        let parts = (text ?? "").split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]),
              (0..<24).contains(h), (0..<60).contains(m) else { return nil }
        return (h, m)
    }

    /// Hour and minute → zero-padded `HH:MM`.
    public static func formatTime(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }
}
