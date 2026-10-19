import SwiftUI
import FusionhaKit

/// Settings → Notifications (`NotificationsPanel.tsx`, ruling A9: the web's
/// model): the Web Push master switch (admins), this device's native push and
/// the other devices, the admin delivery card, the Events switches, then
/// Grouping & timing with the digest time and sample, and the APNs key for
/// admins. Web Push devices are browser subscriptions, listed read-only.
struct NotificationsPanel: View {
    @Environment(AppModel.self) private var model
    @State private var devices: [PushSubscriptionInfo] = []
    @State private var settings: WebPushSettings?
    @State private var loaded = false
    @State private var rotating = false
    @State private var toaster = FetchToaster()
    @State private var confirm: FetchConfirm?
    @State private var rows = NotificationRowsStore()
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
            if !loaded { FetchLoading() }

            if isAdmin {
                NotifCard {
                    NotifRow(name: "Web Push", desc: "Master switch · admins. Each person enables their own devices.") {
                        Toggle("Enable Web Push", isOn: Binding(get: { settings?.enabled ?? false },
                                                                set: { update(["enabled": .bool($0)]) }))
                            .labelsHidden().tint(Theme.indigo)
                    }
                }
                .fetchReveal(0)
                .padding(.bottom, 4)
            }

            deviceSections

            Group {
                AdminDeliveryCard(store: rows)
                NotificationEventsList(store: rows)
            }
            .fetchReveal(3)

            Group {
                if isAdmin {
                    ChannelPolicyCard(settings: settings, rotating: rotating, update: update, rotate: confirmRotate) {
                        sample
                    }
                    ApnsAdminCard(settings: apnsSettings, update: updateApns) { editingApns = true }
                } else {
                    sample
                }
            }
            .fetchReveal(4)
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

    @ViewBuilder
    private var sample: some View {
        if let digest = rows.digest { DigestSampleCard(preview: digest) }
    }

    @ViewBuilder
    private var deviceSections: some View {
        NotifSec("This device")
        NotifCard {
            ThisDeviceNativeCard(push: push, isAdmin: isAdmin, onSetUpApns: { editingApns = true }) { message, ok in
                toaster.show(message, tone: ok ? .success : .error)
            }
        }
        .fetchReveal(1)

        if !push.otherDevices.isEmpty {
            NotifSec("Other iOS devices")
            NotifCard {
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
            NotifSec("Web Push devices")
            NotifCard {
                ForEach(Array(devices.enumerated()), id: \.element.id) { index, device in
                    if index > 0 { Divider().overlay(Theme.line) }
                    WebPushDeviceRow(device: device)
                }
            }
            .fetchReveal(2)
            Text("Browsers you enabled push on. Manage them from the web app on that device. A device you remove or that expires disappears here automatically.")
                .font(.system(size: 11.5)).foregroundStyle(Theme.dim)
                .padding(.top, 8)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Actions

    private func load() async {
        guard let client = model.client else { return }
        devices = (try? await client.pushSubscriptions()) ?? []
        if isAdmin {
            settings = try? await client.webPushSettings()
            apnsSettings = try? await client.apnsSettings()
        }
        await push.load(client)
        await rows.load(client)
        loaded = true
    }

    private func update(_ body: [String: SettingsJSON]) {
        guard let client = model.client else { return }
        Task {
            do {
                settings = try await client.updateWebPushSettings(.object(body))
                if body["digest_time"] != nil { await rows.refreshDigest(client) }
            } catch {
                toaster.show("Couldn't save that change. Try again.", tone: .error)
            }
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

    private func confirmRotate() {
        confirm = FetchConfirm(title: "Rotate the Web Push keys?",
                               message: "Every device stops receiving pushes until it is re-enabled.",
                               action: "Rotate keys") { rotate() }
    }

    private func rotate() {
        guard let client = model.client else { return }
        rotating = true
        Task {
            do {
                let r = try await client.rotateVapidKeys()
                toaster.show("Keys rotated — \(r.invalidated) device\(r.invalidated == 1 ? "" : "s") must re-enable")
                await load()
            } catch {
                toaster.show("Couldn't rotate the keys. Try again.", tone: .error)
            }
            rotating = false
        }
    }
}
