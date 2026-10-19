import SwiftUI
import FusionhaKit

/// One browser Web Push subscription, read-only (web `OtherDevicesSection`):
/// its label and delivery health from the signals, not the bare flag.
struct WebPushDeviceRow: View {
    let device: PushSubscriptionInfo

    var body: some View {
        let status = Self.status(device)
        let ua = device.userAgent ?? ""
        let phone = ua.range(of: "iP(hone|ad)|Android", options: .regularExpression) != nil
        HStack(spacing: 10) {
            Image(systemName: phone ? "iphone" : "laptopcomputer").font(.system(size: 16)).foregroundStyle(Theme.mut)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.deviceLabel?.isEmpty == false ? device.deviceLabel! : "Device")
                    .font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                Text(status.label).font(.system(size: 11.5)).foregroundStyle(Theme.mut)
            }
            Spacer(minLength: 0)
            Circle().fill(status.color).frame(width: 8, height: 8).accessibilityHidden(true)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    /// Delivery health (`otherDeviceHealth`).
    static func status(_ s: PushSubscriptionInfo) -> (label: String, color: Color) {
        let staleSeconds: TimeInterval = 30 * 86_400
        func stale(_ iso: String?) -> Bool {
            guard let d = FetchFormat.date(iso) else { return false }
            return Date.now.timeIntervalSince(d) >= staleSeconds
        }
        let active = FetchFormat.ago(s.lastSuccessAt ?? s.lastSeenAt ?? s.createdAt)
        if s.disabled == true { return ("Disabled", Theme.dim) }
        if (s.failureCount ?? 0) >= 3 { return ("Not delivering · last active \(active)", Theme.dim) }
        let isStale = s.lastSuccessAt != nil ? stale(s.lastSuccessAt) : stale(s.createdAt)
        if isStale { return ("Maybe inactive · last active \(active)", Theme.miss) }
        return ("Enabled · active \(active)", Theme.done)
    }
}

/// Admin "iOS app push (APNs)" (web `IosPushSection`): the switch and where
/// the key is set up.
struct ApnsAdminCard: View {
    let settings: ApnsSettings?
    let update: ([String: SettingsJSON]) -> Void
    let configure: () -> Void

    var body: some View {
        NotifSec("iOS app push (APNs)")
        NotifCard {
            NotifRow(name: "Apple Push", desc: settings?.configured == true
                ? "Configured · key \(settings?.keyId ?? "") · team \(settings?.teamId ?? "")"
                : "Not configured · needs the APNs auth key (.p8), Key ID and Team ID") {
                Toggle("Enable iOS push", isOn: Binding(get: { settings?.enabled ?? true },
                                                        set: { update(["enabled": .bool($0)]) }))
                    .labelsHidden().tint(Theme.indigo)
            }
            Divider().overlay(Theme.line)
            NotifRow(name: "Bundle ID · environment",
                     desc: "\(settings?.topic ?? "org.elabx.fusionha") · \(settings?.environment ?? "auto")") {
                Button("Configure", action: configure).buttonStyle(.web(.ghost))
            }
        }
    }
}
