import SwiftUI
import FusionhaKit

/// Settings → Notifications (`NotificationsPanel.tsx`): this user's push event
/// matrix and Send test; the Web Push master switch, grouping, quiet hours and key
/// rotation for admins. Web Push devices are browser subscriptions, so this app
/// lists them read-only instead of enabling itself as one.
struct NotificationsPanel: View {
    @Environment(AppModel.self) private var model
    @State private var prefs: [String: Bool] = [:]
    @State private var devices: [PushSubscriptionInfo] = []
    @State private var settings: WebPushSettings?
    @State private var loaded = false
    @State private var error: String?
    @State private var testing = false
    @State private var testResult: ConnectionTestResult?
    @State private var rotating = false
    @State private var toaster = FetchToaster()
    @State private var confirm: FetchConfirm?

    private var isAdmin: Bool {
        guard let me = model.me else { return false }
        return me.isAdmin || (me.permissions ?? []).contains("settings.manage")
    }

    /// The curated push event matrix (mock order) → backend `event_kind`.
    private static let events: [(key: String, label: String, hint: String, sev: Color, tag: String?)] = [
        ("grab", "Grabbed", "A release was sent to the download client", Theme.grab, nil),
        ("import", "Imported", "A file was imported into the library", Theme.done, nil),
        ("failed", "Download failed", "A grab or import failed", Theme.danger, nil),
        ("upgrade", "Upgrade found", "A better release replaced an existing file", Theme.grab, nil),
        ("needs_attention", "Needs attention", "A manual import or a stuck item needs you", Theme.miss, nil),
        ("request_available", "Request available", "A title someone requested is now downloaded", Theme.anime, "· requestors"),
        ("request_made", "New request", "A user submitted a new media request", Theme.anime, "· admins"),
    ]

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
            card { thisDevice }.fetchReveal(1)

            if !devices.isEmpty {
                sec("Web Push devices")
                card {
                    ForEach(Array(devices.enumerated()), id: \.element.id) { index, device in
                        if index > 0 { Divider().overlay(Theme.line) }
                        deviceRow(device)
                    }
                }
                .fetchReveal(2)
                Text("Browsers you enabled push on. Manage them from the web app on that device — a device you remove or that expires disappears here automatically.")
                    .font(.system(size: 11.5)).foregroundStyle(Theme.dim)
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)
            }

            sec("Events")
            card {
                ForEach(Array(Self.events.enumerated()), id: \.element.key) { index, event in
                    if index > 0 { Divider().overlay(Theme.line) }
                    HStack(alignment: .center, spacing: 10) {
                        RoundedRectangle(cornerRadius: 2).fill(event.sev).frame(width: 3, height: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(event.label).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                                if let tag = event.tag { Text(tag).font(.system(size: 11)).foregroundStyle(Theme.dim) }
                            }
                            Text(event.hint).font(.system(size: 12)).foregroundStyle(Theme.mut)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                        Toggle(event.label, isOn: Binding(get: { prefs[event.key] ?? true },
                                                          set: { togglePref(event.key, $0) }))
                            .labelsHidden().tint(Theme.indigo)
                    }
                    .padding(.vertical, 10)
                }
            }
            .fetchReveal(3)

            if isAdmin { adminSection }
        }
        .task { await load() }
    }

    // MARK: This device

    @ViewBuilder
    private var thisDevice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "iphone").font(.system(size: 18)).foregroundStyle(Theme.mut)
                .frame(width: 36, height: 36)
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(UIDevice.current.name).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                Text("This app").font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
            Spacer(minLength: 0)
            FetchPill(text: "● Web only", tone: .off)
        }
        .padding(.vertical, 8)
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle").foregroundStyle(Theme.cyan)
            Text("Web Push is a browser channel. Open fusionha in Safari on this iPhone, add it to the Home Screen and enable push there; your event choices below apply to every device.")
                .font(.system(size: 12)).foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Theme.cyan.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        HStack(spacing: 10) {
            Button { runTest() } label: { Label("Send test", systemImage: "bolt.fill") }
                .buttonStyle(.web(.primary))
                .disabled(testing)
            if testing {
                ProgressView().controlSize(.mini)
                Text("Sending…").font(.system(size: 12)).foregroundStyle(Theme.mut)
            } else if let testResult {
                Label(testResult.message, systemImage: testResult.ok ? "checkmark" : "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(testResult.ok ? Theme.done : Theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
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
            .tint(Theme.cyan)
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
                .font(.system(size: 10.5, weight: .heavy))
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
        do {
            let p = try await client.notificationPreferences()
            prefs = Dictionary(p.preferences.map { ($0.eventKind, $0.enabled) }, uniquingKeysWith: { _, b in b })
            error = nil
        } catch {
            self.error = error.settingsMessage
        }
        devices = (try? await client.pushSubscriptions()) ?? []
        if isAdmin { settings = try? await client.webPushSettings() }
        loaded = true
    }

    private func togglePref(_ key: String, _ on: Bool) {
        guard let client = model.client else { return }
        let before = prefs[key]
        prefs[key] = on
        Task {
            do {
                let fresh = try await client.setNotificationPreference(event: key, enabled: on)
                prefs = Dictionary(fresh.preferences.map { ($0.eventKind, $0.enabled) }, uniquingKeysWith: { _, b in b })
            } catch {
                prefs[key] = before
                toaster.error(error)
            }
        }
    }

    private func update(_ body: [String: SettingsJSON]) {
        guard let client = model.client else { return }
        Task {
            do { settings = try await client.updateWebPushSettings(.object(body)) } catch { toaster.error(error) }
        }
    }

    private func runTest() {
        guard let client = model.client else { return }
        testing = true
        testResult = nil
        Task {
            do {
                let r = try await client.testPush()
                let message = r.sent == 0
                    ? "No devices to notify — enable push on a device first."
                    : "Sent to \(r.delivered) of \(r.sent) device\(r.sent == 1 ? "" : "s")"
                testResult = ConnectionTestResult(ok: r.delivered > 0, message: message)
                toaster.show(message, tone: r.delivered > 0 ? .success : .error)
            } catch {
                testResult = ConnectionTestResult(ok: false, message: error.settingsMessage)
                toaster.error(error)
            }
            testing = false
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
