import SwiftUI
import FusionhaKit

/// The requester's notifications, inline in Account (web
/// `RequesterNotifications.tsx`): this device, the user's other iOS devices,
/// and an on/off switch per kind the server lists for them. The same sections
/// as Settings › Notifications with no admin or channel settings, so a
/// requester never lands in Settings.
struct RequesterNotificationsSection: View {
    @Environment(AppModel.self) private var model
    /// Shows a toast from the host screen (sheets hide the app's own toasts).
    let notify: (_ message: String, _ ok: Bool) -> Void
    @State private var push = NativePushState()
    @State private var removing: ApnsDevice?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Notifications")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.txt)
                .padding(.top, 26)
                .accessibilityAddTraits(.isHeader)

            NotificationsSectionLabel("This device")
            card { ThisDeviceNativeCard(push: push, notify: notify) }

            if !push.otherDevices.isEmpty {
                NotificationsSectionLabel("Other iOS devices")
                card {
                    ForEach(Array(push.otherDevices.enumerated()), id: \.element.id) { index, device in
                        if index > 0 { Divider().overlay(Theme.line) }
                        ApnsDeviceRow(device: device) { removing = device }
                    }
                }
                Text("A device you remove or that expires disappears here automatically — the same device never shows twice.")
                    .font(.system(size: 11.5)).foregroundStyle(Theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }

            NotificationsSectionLabel("Events")
            NotificationEventSwitches(notify: notify)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { await push.load(model.client) }
        .confirmationDialog("Remove \(removing?.deviceName ?? "this device")?",
                            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                            titleVisibility: .visible, presenting: removing) { device in
            Button("Remove", role: .destructive) { remove(device) }
        } message: { _ in
            Text("It stops receiving notifications until the app registers again.")
        }
    }

    private func card<C: View>(@ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Theme.line))
    }

    private func remove(_ device: ApnsDevice) {
        Task {
            do { try await push.remove(device, client: model.client) } catch {
                notify(ErrorCopy.message(for: error, fallback: "Couldn’t remove the device."), false)
            }
        }
    }
}

/// The web's `Sec`: an uppercase section label with a trailing hairline.
struct NotificationsSectionLabel: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
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
        .accessibilityAddTraits(.isHeader)
    }
}
