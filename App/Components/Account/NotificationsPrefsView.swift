import SwiftUI
import UIKit
import UserNotifications
import FusionhaKit

/// Account › Notifications: whether iOS allows them, whether this iPhone is
/// registered with the server, and a test. Which events notify is a server
/// setting for now (Settings › Notifications).
struct NotificationsPrefsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    let openServerSettings: () -> Void
    @State private var status: UNAuthorizationStatus?

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    Circle().fill(allowed ? Theme.done : Theme.miss).frame(width: 8, height: 8)
                    Text(statusText)
                    Spacer(minLength: 0)
                }
                if PushRegistration.deviceToken != nil {
                    Label("This iPhone is registered for push", systemImage: "checkmark.seal")
                        .foregroundStyle(Theme.mut)
                } else if let error = PushRegistration.registrationError {
                    Text(error).font(.footnote).foregroundStyle(Theme.mut)
                }
                Button("Notification settings in iOS") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
            }
            .listRowBackground(AccountStyle.cell)

            if allowed, PushRegistration.deviceToken != nil {
                Section {
                    ActAsyncButton(label: "Send a test notification", systemImage: "bell.badge") {
                        guard let client = model.client,
                              let device = await PushRegistration.register(with: client) else { return false }
                        return (try? await client.testApns(deviceId: device.id)) != nil
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .listRowBackground(AccountStyle.cell)
            }

            Section {
                Button("Choose which events notify", action: openServerSettings)
            } footer: {
                Text("Imports, held downloads, failures and requests are chosen on the server, in Settings › Notifications.")
            }
            .listRowBackground(AccountStyle.cell)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { status = await PushRegistration.authorizationStatus() }
    }

    private var allowed: Bool { status == .authorized || status == .provisional || status == .ephemeral }

    private var statusText: String {
        switch status {
        case .authorized, .provisional, .ephemeral: return "Allowed in iOS"
        case .denied: return "Turned off in iOS"
        case .notDetermined: return "Not asked yet"
        default: return "Checking…"
        }
    }
}
