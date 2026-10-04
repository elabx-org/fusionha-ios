import Combine
import SwiftUI
import UserNotifications
import FusionhaKit

/// Settings → Notifications (`NotificationsPanel.tsx`): this device's native push
/// (APNs) state and Send test, this user's other iOS devices, the shared push
/// event matrix; the Web Push master switch, grouping, quiet hours, key rotation
/// and the APNs key for admins. Web Push devices are browser subscriptions, so
/// this app lists them read-only.
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
    // Native push (APNs).
    @State private var apnsStatus: ApnsStatus?
    @State private var apnsDevices: [ApnsDevice] = []
    @State private var apnsSettings: ApnsSettings?
    @State private var authStatus: UNAuthorizationStatus?
    @State private var registering = false
    @State private var editingApns = false

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

            if !otherApnsDevices.isEmpty {
                sec("Other iOS devices")
                card {
                    ForEach(Array(otherApnsDevices.enumerated()), id: \.element.id) { index, device in
                        if index > 0 { Divider().overlay(Theme.line) }
                        apnsDeviceRow(device)
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
        .sheet(isPresented: $editingApns) {
            ApnsSettingsSheet(settings: apnsSettings) { saved in
                apnsSettings = saved
                toaster.show("iOS push settings saved")
                Task { await load() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .apnsTokenChanged)) { _ in
            Task {
                try? await Task.sleep(for: .milliseconds(600)) // let AppModel register first
                await load()
            }
        }
    }

    // MARK: This device (native push)

    private var deviceToken: String? { PushRegistration.deviceToken }

    /// This install's row on the server, matched by APNs token.
    private var thisApnsDevice: ApnsDevice? {
        guard let token = deviceToken else { return nil }
        return apnsDevices.first { $0.deviceToken == token }
    }

    private var otherApnsDevices: [ApnsDevice] {
        apnsDevices.filter { $0.deviceToken != deviceToken }
    }

    private enum NativeState {
        case loading, serverNotConfigured(String), serverOff(String), denied, notAsked
        case noEntitlement(String), registering, enabled(ApnsDevice)
    }

    private var nativeState: NativeState {
        guard let status = apnsStatus, let authStatus else { return .loading }
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
        if let device = thisApnsDevice { return .enabled(device) }
        if deviceToken == nil, let error = PushRegistration.registrationError { return .noEntitlement(error) }
        return .registering
    }

    @ViewBuilder
    private var thisDevice: some View {
        let state = nativeState
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "iphone").font(.system(size: 18)).foregroundStyle(Theme.mut)
                .frame(width: 36, height: 36)
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(UIDevice.current.name).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                Text(thisDeviceMeta(state)).font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
            Spacer(minLength: 0)
            thisDevicePill(state)
        }
        .padding(.vertical, 8)
        if let note = thisDeviceNote(state) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: note.warn ? "exclamationmark.triangle" : "info.circle")
                    .foregroundStyle(note.warn ? Theme.miss : Theme.cyan)
                Text(note.text)
                    .font(.system(size: 12)).foregroundStyle(Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background((note.warn ? Theme.miss : Theme.cyan).opacity(0.07),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        HStack(spacing: 10) {
            switch state {
            case .notAsked:
                Button { enableNotifications() } label: { Label("Enable notifications", systemImage: "bell.badge") }
                    .buttonStyle(.web(.primary))
            case .denied:
                Button { openNotificationSettings() } label: { Label("Open iOS Settings", systemImage: "gear") }
                    .buttonStyle(.web(.primary))
            case .serverNotConfigured:
                if isAdmin {
                    Button { editingApns = true } label: { Label("Set up APNs", systemImage: "key") }
                        .buttonStyle(.web(.primary))
                }
            case .registering:
                Button { Task { await register() } } label: { Label("Register this device", systemImage: "arrow.clockwise") }
                    .buttonStyle(.web(.primary))
                    .disabled(registering)
            case .enabled:
                Button { runTest() } label: { Label("Send test", systemImage: "bolt.fill") }
                    .buttonStyle(.web(.primary))
                    .disabled(testing)
            case .loading, .serverOff, .noEntitlement:
                EmptyView()
            }
            if testing || registering {
                ProgressView().controlSize(.mini)
                Text(testing ? "Sending…" : "Registering…").font(.system(size: 12)).foregroundStyle(Theme.mut)
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

    private func thisDeviceMeta(_ state: NativeState) -> String {
        switch state {
        case .enabled(let d):
            let active = FetchFormat.ago(d.lastSuccessAt ?? d.lastSeenAt ?? d.createdAt)
            return "This app · \(d.environment) · active \(active)"
        default:
            return "This app"
        }
    }

    @ViewBuilder
    private func thisDevicePill(_ state: NativeState) -> some View {
        switch state {
        case .loading: ProgressView().controlSize(.mini)
        case .enabled(let d):
            if let error = d.lastError, (d.failureCount ?? 0) > 0 {
                FetchPill(text: "● Not delivering", tone: .warn).accessibilityHint(error)
            } else {
                FetchPill(text: "● Enabled", tone: .ok)
            }
        case .serverNotConfigured: FetchPill(text: "● Server not set up", tone: .warn)
        case .serverOff: FetchPill(text: "● Off on server", tone: .off)
        case .denied: FetchPill(text: "● Blocked", tone: .err)
        case .notAsked: FetchPill(text: "● Off", tone: .off)
        case .noEntitlement: FetchPill(text: "● Unavailable", tone: .err)
        case .registering: FetchPill(text: "● Not registered", tone: .off)
        }
    }

    private func thisDeviceNote(_ state: NativeState) -> (text: String, warn: Bool)? {
        switch state {
        case .serverNotConfigured(let message):
            return (message + (isAdmin
                ? " Add the APNs auth key (.p8), Key ID and Team ID from your Apple Developer account."
                : " Ask an admin to add the APNs key in Settings → Notifications."), true)
        case .serverOff(let message): return (message, true)
        case .denied:
            return ("Notifications for fusionha are turned off in iOS Settings. Turn them on there to get pushes on this device.", true)
        case .notAsked:
            return ("Get grabs, imports, failures and requests as native notifications on this device. Your event choices below apply to every device.", false)
        case .noEntitlement(let error):
            return ("iOS didn't issue a push token (\(error)). The build must be signed with a profile that has Push Notifications enabled for org.elabx.fusionha.", true)
        case .enabled(let d):
            if let error = d.lastError, (d.failureCount ?? 0) > 0 {
                return ("Last delivery failed: \(error)", true)
            }
            return nil
        case .loading, .registering: return nil
        }
    }

    private func apnsDeviceRow(_ device: ApnsDevice) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "iphone").font(.system(size: 16)).foregroundStyle(Theme.mut).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.deviceName?.isEmpty == false ? device.deviceName! : "iPhone")
                    .font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                Text("fusionha app · \(device.environment) · active \(FetchFormat.ago(device.lastSuccessAt ?? device.lastSeenAt ?? device.createdAt))")
                    .font(.system(size: 11.5)).foregroundStyle(Theme.mut).lineLimit(1)
            }
            Spacer(minLength: 0)
            FetchIconButton(systemName: "trash", label: "Remove \(device.deviceName ?? "device")", danger: true) {
                confirm = FetchConfirm(title: "Remove \(device.deviceName ?? "this device")?",
                                       message: "It stops receiving notifications until the app registers again.",
                                       action: "Remove") { removeApnsDevice(device) }
            }
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
        if isAdmin {
            settings = try? await client.webPushSettings()
            apnsSettings = try? await client.apnsSettings()
        }
        do {
            apnsStatus = try await client.apnsStatus()
        } catch APIError.http(404, _) {
            apnsStatus = ApnsStatus(configured: false, enabled: false, topic: "", environment: "", missing: [],
                                    message: "This fusionha server doesn't support native iOS push yet — update it.")
        } catch {
            apnsStatus = ApnsStatus(configured: false, enabled: false, topic: "", environment: "", missing: [],
                                    message: "Couldn't check the server's push setup (\(error.settingsMessage)).")
        }
        apnsDevices = (try? await client.apnsDevices()) ?? []
        authStatus = await PushRegistration.authorizationStatus()
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
                let r = try await client.testApns(deviceId: thisApnsDevice?.id)
                let failure = r.devices?.first { !$0.ok }?.detail
                let message = r.sent == 0
                    ? "This device isn't registered yet."
                    : r.delivered > 0 ? "Sent — check your notifications" : (failure ?? "Not delivered")
                testResult = ConnectionTestResult(ok: r.delivered > 0, message: message)
                toaster.show(message, tone: r.delivered > 0 ? .success : .error)
            } catch {
                testResult = ConnectionTestResult(ok: false, message: error.settingsMessage)
                toaster.error(error)
            }
            testing = false
            await load()
        }
    }

    private func enableNotifications() {
        Task {
            let granted = (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            if granted { UIApplication.shared.registerForRemoteNotifications() }
            authStatus = await PushRegistration.authorizationStatus()
        }
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func register() async {
        guard let client = model.client else { return }
        registering = true
        if PushRegistration.deviceToken == nil {
            await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
        } else if await PushRegistration.register(with: client) == nil {
            toaster.show("Couldn't register this device", tone: .error)
        }
        registering = false
        await load()
    }

    private func removeApnsDevice(_ device: ApnsDevice) {
        guard let client = model.client else { return }
        Task {
            do {
                try await client.deleteApnsDevice(id: device.id)
                apnsDevices.removeAll { $0.id == device.id }
            } catch { toaster.error(error) }
        }
    }

    private func updateApns(_ body: [String: SettingsJSON]) {
        guard let client = model.client else { return }
        Task {
            do {
                apnsSettings = try await client.updateApnsSettings(.object(body))
                apnsStatus = try? await client.apnsStatus()
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
