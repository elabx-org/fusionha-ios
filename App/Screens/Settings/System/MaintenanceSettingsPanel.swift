import SwiftUI
import WebKit
import FusionhaKit

// MARK: Maintenance

/// Version, update status and the reset-cache tools. On iOS the "cache" is the
/// artwork and HTTP caches plus the in-app web panels' storage; a reset then
/// reloads the library. The full reset also clears this device's preferences
/// and signs the web panels out (the app sign-in is kept).
struct MaintenanceSettingsPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(SettingsStore.self) private var store
    @State private var serverVersion: String?
    @State private var confirmFull = false
    @State private var done: String?

    var body: some View {
        SettingsForm(slug: "maintenance") {
            SettingsSection {
                SettingValueRow(label: "Version", description: "The version of the app currently running on this device.") {
                    MonoText(Bundle.main.appVersion)
                }
                SettingValueRow(label: "Update status",
                                description: "The fusionha server this app is connected to. App updates arrive through your Feather source.") {
                    if let serverVersion {
                        SettingsStatusPill(text: "Server v\(serverVersion)")
                    } else {
                        MonoText("—")
                    }
                }
            }
            SettingsSection("Reset") {
                SettingValueRow(label: "Reset cache & reload",
                                description: "Clears the app's cached files and reloads a fresh copy. Fixes a UI that's stuck on an old version. Keeps you signed in and preserves your preferences.") {
                    Button("Reset cache & reload") { Task { await reset(full: false) } }
                        .buttonStyle(.web(.primary))
                }
                SettingValueRow(label: "Advanced: full reset",
                                description: "Everything the safe reset does, and also clears locally-stored preferences (theme, view options). Use only if a normal reset didn't help.") {
                    Button("Full reset…") { confirmFull = true }
                        .buttonStyle(.web(.danger))
                }
                if let done {
                    Label(done, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.done)
                }
            }
        }
        .alert("Full reset?", isPresented: $confirmFull) {
            Button("Cancel", role: .cancel) {}
            Button("Full reset & reload", role: .destructive) { Task { await reset(full: true) } }
        } message: {
            Text("This clears the app cache and all locally-stored preferences (theme, view options), then reloads. Your library and server settings are not affected. You may need to sign in and re-pick your preferences.")
        }
        .task {
            serverVersion = try? await store.client?.health().version
        }
    }

    private func reset(full: Bool) async {
        URLCache.shared.removeAllCachedResponses()
        var types = WKWebsiteDataStore.allWebsiteDataTypes()
        if !full { types.remove(WKWebsiteDataTypeCookies) }
        await WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: .distantPast)
        if full, let bundle = Bundle.main.bundleIdentifier {
            // Device preferences only; the sign-in lives in the Keychain and App Group.
            let keep = ["serverURL", "tokenId", "authMethod"]
            let saved = keep.reduce(into: [String: Any]()) { $0[$1] = UserDefaults.standard.object(forKey: $1) }
            UserDefaults.standard.removePersistentDomain(forName: bundle)
            for (k, v) in saved { UserDefaults.standard.set(v, forKey: k) }
        }
        await store.load()
        await model.loadMe()
        await model.loadLibrary()
        withAnimation(.easeOut(duration: 0.2)) { done = full ? "Full reset done, reloaded." : "Cache cleared, reloaded." }
    }
}
