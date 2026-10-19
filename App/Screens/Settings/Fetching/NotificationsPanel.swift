import SwiftUI
import FusionhaKit

/// Settings → Notifications (`NotificationsPanel.tsx`): this device's native push
/// (APNs) state and Send test, this user's other iOS devices, the shared push
/// event matrix; the Web Push master switch, grouping, quiet hours, key rotation
/// and the APNs key for admins. Web Push devices are browser subscriptions, so
/// this app lists them read-only.
struct NotificationsPanel: View {
    @Environment(AppModel.self) private var model
    @State private var devices: [PushSubscriptionInfo] = []
    @State private var settings: WebPushSettings?
    @State private var loaded = false
    @State private var error: String?
    @State private var rotating = false
    @State private var toaster = FetchToaster()
    @State private var confirm: FetchConfirm?
    // Native push (APNs).
    @State private var push = NativePushState()
    @State private var apnsSettings: ApnsSettings?
    @State private var editingApns = false

    private var isAdmin: Bool {
        guard let me = model.me else { return false }
        return me.isAdmin || (me.permissions ?? []).contains("settings.manage")
    }

    var body: some View {
        FetchingPage(slug: "notifications", toaster: toaster, confirm: $confirm, refresh: load) {
            if !loaded || error != nil { FetchLoading(error: error) }

            if isAdmin {
                card {
                    row(name: "Web Push", desc: "Master switch · admins. Each person enables their own devices.") {
                        Toggle("Enable Web Push", isOn: Binding(get: { settings?.enabled ?? false },
                                                                set: { update(["enabled": .bool($0)]) }))
                            .labelsHidden().tint(Theme.indigo)
                    }
                }
                .fetchReveal(0)
                .padding(.bottom, 4)
            }

            sec("This device")
            card {
                ThisDeviceNativeCard(push: push, isAdmin: isAdmin, onSetUpApns: { editingApns = true }) { message, ok in
                    toaster.show(message, tone: ok ? .success : .error)
                }
            }
            .fetchReveal(1)

            if !push.otherDevices.isEmpty {
                sec("Other iOS devices")
                card {
                    ForEach(Array(push.otherDevices.enumerated()), id: \.element.id) { index, device in
                        if index > 0 { Divider().overlay(Theme.line) }
                        ApnsDeviceRow(device: device) {
                            confirm = FetchConfirm(title: "Remove \(device.deviceName ?? "this device")?",
                                                   message: "It stops receiving notifications until the app registers again.",
                                                   action: "Remove") { removeApnsDevice(device) }
                        }
                    }
                }
                .fetchReveal(2)
            }

            if !devices.isEmpty {
                sec("Web Push devices")
                card {
                    ForEach(Array(devices.enumerated()), id: \.element.id) { index, device in
                        if index > 0 { Divider().overlay(Theme.line) }
                        deviceRow(device)
                    }
                }
                .fetchReveal(2)
                Text("Browsers you enabled push on. Manage them from the web app on that device. A device you remove or that expires disappears here automatically.")
                    .font(.system(size: 11.5)).foregroundStyle(Theme.dim)
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)
            }

            sec("Events")
            NotificationEventsCard()
            .fetchReveal(3)

            if isAdmin { adminSection }
        }
        .task { await load() }
        .sheet(isPresented: $editingApns) {
            ApnsSettingsSheet(settings: apnsSettings) { saved in
                apnsSettings = saved
                toaster.show("iOS push settings saved")
                Task { await load() }
            }
        }
    }

    private func deviceRow(_ device: PushSubscriptionInfo) -> some View {
        let status = deviceStatus(device)
        let ua = device.userAgent ?? ""
        let phone = ua.range(of: "iP(hone|ad)|Android", options: .regularExpression) != nil
        return HStack(spacing: 10) {
            Image(systemName: phone ? "iphone" : "laptopcomputer").font(.system(size: 16)).foregroundStyle(Theme.mut)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.deviceLabel?.isEmpty == false ? device.deviceLabel! : "Device")
                    .font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                Text(status.label).font(.system(size: 11.5)).foregroundStyle(Theme.mut)
            }
            Spacer(minLength: 0)
            Circle().fill(status.color).frame(width: 8, height: 8)
        }
        .padding(.vertical, 10)
    }

    /// Delivery health from the signals (`otherDeviceHealth`), not the bare flag.
    private func deviceStatus(_ s: PushSubscriptionInfo) -> (label: String, color: Color) {
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

    // MARK: Admin

    @ViewBuilder
    private var adminSection: some View {
        sec("iOS app push (APNs)")
        card {
            row(name: "Apple Push", desc: apnsSettings?.configured == true
                ? "Configured · key \(apnsSettings?.keyId ?? "") · team \(apnsSettings?.teamId ?? "")"
                : "Not configured · needs the APNs auth key (.p8), Key ID and Team ID") {
                Toggle("Enable iOS push", isOn: Binding(get: { apnsSettings?.enabled ?? true },
                                                        set: { updateApns(["enabled": .bool($0)]) }))
                    .labelsHidden().tint(Theme.indigo)
            }
            Divider().overlay(Theme.line)
            row(name: "Bundle ID · environment",
                desc: "\(apnsSettings?.topic ?? "org.elabx.fusionha") · \(apnsSettings?.environment ?? "auto")") {
                Button("Configure") { editingApns = true }
                    .buttonStyle(.web(.ghost))
            }
        }
        .fetchReveal(4)
        sec("Grouping & timing")
        card {
            VStack(alignment: .leading, spacing: 8) {
                FieldLabel(label: "Delivery", description: "How multiple events are bundled")
                Picker("Delivery grouping", selection: Binding(get: { settings?.grouping ?? "group_by_title" },
                                                               set: { update(["grouping": .string($0)]) })) {
                    Text("Immediate").tag("immediate")
                    Text("Group by title").tag("group_by_title")
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 10)
            Divider().overlay(Theme.line)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    FieldLabel(label: "Quiet hours", description: "Hold non-urgent pushes overnight")
                    Spacer()
                    Toggle("Enable quiet hours", isOn: Binding(get: { settings?.quietHoursEnabled ?? false },
                                                               set: { update(["quiet_hours_enabled": .bool($0)]) }))
                        .labelsHidden().tint(Theme.indigo)
                }
                HStack(spacing: 8) {
                    timePicker("Quiet hours start", key: "quiet_hours_start", value: settings?.quietHoursStart)
                    Text("→").foregroundStyle(Theme.dim)
                    timePicker("Quiet hours end", key: "quiet_hours_end", value: settings?.quietHoursEnd)
                    Spacer()
                }
            }
            .padding(.vertical, 10)
        }
        .fetchReveal(4)
        HStack {
            Button(rotating ? "Rotating…" : "Rotate keys") {
                confirm = FetchConfirm(title: "Rotate the Web Push keys?",
                                       message: "Every device stops receiving pushes until it is re-enabled.",
                                       action: "Rotate keys") { rotate() }
            }
            .buttonStyle(.web(.ghost))
            .disabled(rotating)
            Spacer()
        }
        .padding(.top, 12)
    }

    private func timePicker(_ label: String, key: String, value: String?) -> some View {
        let binding = Binding<Date>(
            get: { Self.date(from: value) },
            set: { update([key: .string(Self.hhmm($0))]) })
        return DatePicker(label, selection: binding, displayedComponents: .hourAndMinute)
            .labelsHidden()
            .tint(Theme.indigo)
    }

    private static func date(from hhmm: String?) -> Date {
        let parts = (hhmm ?? "").split(separator: ":").compactMap { Int($0) }
        let cal = Calendar.current
        return cal.date(bySettingHour: parts.first ?? 22, minute: parts.count > 1 ? parts[1] : 0, second: 0, of: .now) ?? .now
    }

    private static func hhmm(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    // MARK: Layout bits

    private func sec(_ title: String) -> some View {
        HStack(spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(Theme.dim)
                .fixedSize()
            Rectangle().fill(Theme.line).frame(height: 1)
        }
        .padding(.top, 20)
        .padding(.bottom, 9)
    }

    private func card<C: View>(@ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Theme.line))
    }

    private func row<T: View>(name: String, desc: String, @ViewBuilder trailing: () -> T) -> some View {
        HStack(spacing: 10) {
            FieldLabel(label: name, description: desc)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.vertical, 8)
    }

    // MARK: Actions

    private func load() async {
        guard let client = model.client else { return }
        error = nil
        devices = (try? await client.pushSubscriptions()) ?? []
        if isAdmin {
            settings = try? await client.webPushSettings()
            apnsSettings = try? await client.apnsSettings()
        }
        await push.load(client)
        loaded = true
    }

    private func update(_ body: [String: SettingsJSON]) {
        guard let client = model.client else { return }
        Task {
            do { settings = try await client.updateWebPushSettings(.object(body)) } catch { toaster.error(error) }
        }
    }

    private func removeApnsDevice(_ device: ApnsDevice) {
        guard let client = model.client else { return }
        Task {
            do { try await push.remove(device, client: client) } catch { toaster.error(error) }
        }
    }

    private func updateApns(_ body: [String: SettingsJSON]) {
        guard let client = model.client else { return }
        Task {
            do {
                apnsSettings = try await client.updateApnsSettings(.object(body))
                await push.refreshStatus(client)
            } catch { toaster.error(error) }
        }
    }

    private func rotate() {
        guard let client = model.client else { return }
        rotating = true
        Task {
            do {
                let r = try await client.rotateVapidKeys()
                toaster.show("Keys rotated — \(r.invalidated) device\(r.invalidated == 1 ? "" : "s") must re-enable")
                await load()
            } catch { toaster.error(error) }
            rotating = false
        }
    }
}
