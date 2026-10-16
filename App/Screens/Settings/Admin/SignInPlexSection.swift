import SwiftUI
import FusionhaKit

/// The Plex provider card (web `PlexProviderCard`): status, the connected
/// server's facts, Configure, and the enable switch. Turning it on is refused
/// until an owner token is connected.
struct SignInPlexSection: View {
    let toaster: FetchToaster
    @Environment(SettingsStore.self) private var store
    @State private var configuring = false
    @State private var pending = false

    private var on: Bool { store.bool("plex_sso_enabled") }
    private var hasToken: Bool { store.bool("plex_owner_token_set") }

    var body: some View {
        SettingsSection {
            SignInProviderHeader(symbol: "play.rectangle.fill", tint: Theme.plexGold, title: "Plex",
                                 pill: on ? "Connected" : "Off", on: on,
                                 description: "Anyone with access to your Plex server can sign in and request titles.")
            if on {
                SettingValueRow(label: "Server") { chip(store.string("plex_server_name").isEmpty ? "Plex" : store.string("plex_server_name")) }
                SettingValueRow(label: "Default role") { chip("Requestor") }
                SettingValueRow(label: "Provisioning") {
                    chip(store.string("plex_provisioning_mode") == "import" ? "Periodic import" : "On first login")
                }
            }
            Toggle("Enable Plex sign-in", isOn: Binding(get: { on }, set: { set($0) }))
                .tint(Theme.indigo)
                .disabled(pending || !store.loaded)
                .settingsField("Enable Plex sign-in")
            Button("Configure", systemImage: "pencil") { configuring = true }
        }
        .sheet(isPresented: $configuring) { PlexSSOConfigSheet(toaster: toaster) }
    }

    private func chip(_ text: String) -> some View {
        Text(text).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.txt)
    }

    private func set(_ next: Bool) {
        if next && !hasToken {
            configuring = true
            toaster.show("Plex SSO needs an owner token before it can be enabled.", title: "Connect a Plex account first", tone: .error)
            return
        }
        Task {
            pending = true
            defer { pending = false }
            do {
                try await SignInSettings.put(["plex_sso_enabled": .bool(next)], store: store)
            } catch {
                toaster.show(error.settingsMessage, title: "Could not update Plex SSO", tone: .error)
            }
        }
    }
}

/// Configure Plex SSO (web `PlexConfigDialog`): the switch, the Plex account,
/// provisioning, managed Home profiles, ineligible-account cleanup, the locked
/// default role and, for a full admin, the manual token + connection test.
struct PlexSSOConfigSheet: View {
    let toaster: FetchToaster
    @Environment(SettingsStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var importing = false
    @State private var pruneConfirming = false
    @State private var pruning = false
    @State private var advanced = false

    private var fullAdmin: Bool { model.me?.isAdmin ?? true }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Let people who can already access your Plex server sign in and request titles — no separate fusionha password.")
                        .foregroundStyle(Theme.mut)
                }
                Section {
                    Toggle(isOn: Binding(get: { store.bool("plex_sso_enabled") },
                                         set: { put(["plex_sso_enabled": .bool($0)], "Could not update Plex SSO") })) {
                        FieldLabel(label: "Enable Sign in with Plex",
                                   description: store.bool("plex_owner_token_set")
                                       ? "Shows the Plex button on the login screen. New sign-ins are auto-provisioned as Requestors."
                                       : "Connect a Plex account below before enabling.")
                    }
                    .tint(Theme.indigo)
                    .disabled(!fullAdmin || (!store.bool("plex_sso_enabled") && !store.bool("plex_owner_token_set")))
                }
                PlexAccountConnectSection(canConnect: fullAdmin, toaster: toaster)
                provisioning
                homeProfiles
                ineligible
                Section {
                    LabeledContent("Requestor", value: "view + request")
                } header: {
                    Text("Default role for new accounts")
                } footer: {
                    Text("Admin-capable roles are refused — Plex sign-in can never create an admin. Elevate individuals afterward in Users.")
                }
                if fullAdmin { PlexSSOAdvancedSection(toaster: toaster, expanded: $advanced) }
            }
            .navigationTitle("Plex SSO")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { SheetDoneButton { dismiss() } } }
            .confirmationDialog("Remove ineligible Plex users?", isPresented: $pruneConfirming, titleVisibility: .visible) {
                Button(pruning ? "Removing…" : "Remove ineligible now", role: .destructive) { Task { await prune() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes auto-provisioned Plex Requestor accounts that no longer have server access (e.g. managed Home profiles you’ve excluded). Accounts you elevated (Manager/Admin) or linked to a login are never removed, nor are real Plex accounts still in your Home.")
            }
            .fetchToasts(toaster)
        }
    }

    private var provisioning: some View {
        Section {
            Picker("Provisioning mode", selection: Binding(
                get: { store.string("plex_provisioning_mode") == "import" ? "import" : "on_login" },
                set: { put(["plex_provisioning_mode": .string($0)], "Could not update the provisioning mode") })) {
                Text("On first login").tag("on_login")
                Text("Periodic import").tag("import")
            }
            .pickerStyle(.segmented)
            if store.string("plex_provisioning_mode") == "import" {
                FieldLabel(label: "Import shared users now",
                           description: "Pre-create Requestor accounts for everyone with access — runs every 60 min automatically.")
                Button(importing ? "Importing…" : "Import now", systemImage: "square.and.arrow.down") { Task { await runImport() } }
                    .disabled(importing)
            }
        } header: {
            Text("Provisioning mode")
        } footer: {
            Text("On first login: create the account when they first sign in. Periodic import: pre-create every shared user on a schedule.")
        }
    }

    private var homeProfiles: some View {
        Section("Managed Home profiles") {
            toggle("plex_allow_home_users", "Allow managed Home profiles to sign in",
                   "Managed / restricted Plex Home profiles (Guest, child, and other profiles with no independent Plex login) can sign in. Off by default. Real Plex accounts in your Home are always allowed — this only gates the managed profiles. You (the owner) always can.",
                   "Could not update managed Home profile access")
            toggle("plex_import_home_users", "Include managed Home profiles in periodic import",
                   "Pre-create accounts for managed / restricted Home profiles during import. Off by default. Real Plex accounts in your Home are imported like shared friends regardless.",
                   "Could not update managed Home profile import")
        }
    }

    private var ineligible: some View {
        Section("Ineligible accounts") {
            toggle("plex_prune_on_import", "Remove ineligible users on import",
                   "When importing, also delete auto-provisioned Plex accounts that can no longer sign in (e.g. excluded managed Home profiles). Never removes accounts you elevated or linked, or real Plex accounts still in your Home.",
                   "Could not update prune-on-import")
            FieldLabel(label: "Clean up now",
                       description: "Run the cleanup on demand — deletes auto-provisioned Plex accounts that no longer have server access.")
            Button("Remove ineligible now", systemImage: "trash", role: .destructive) { pruneConfirming = true }
                .disabled(pruning)
        }
    }

    private func toggle(_ key: String, _ label: String, _ description: String, _ failTitle: String) -> some View {
        Toggle(isOn: Binding(get: { store.bool(key) }, set: { put([key: .bool($0)], failTitle) })) {
            FieldLabel(label: label, description: description)
        }
        .tint(Theme.indigo)
    }

    private func put(_ diff: [String: JSONValue], _ failTitle: String) {
        Task {
            do {
                try await SignInSettings.put(diff, store: store)
            } catch {
                toaster.show(error.settingsMessage, title: failTitle, tone: .error)
            }
        }
    }

    private func runImport() async {
        guard let client = model.client else { return }
        importing = true
        defer { importing = false }
        do {
            let r = try await client.importPlexUsers()
            toaster.show("Imported \(r.created) account\(r.created == 1 ? "" : "s").", title: "Import complete")
        } catch {
            toaster.show(error.settingsMessage, title: "Could not run the import", tone: .error)
        }
    }

    private func prune() async {
        guard let client = model.client else { return }
        pruning = true
        defer { pruning = false }
        do {
            let r = try await client.prunePlexUsers()
            toaster.show(r.summary, title: "Plex cleanup complete")
        } catch {
            toaster.show(error.settingsMessage, title: "Could not remove ineligible accounts", tone: .error)
        }
    }
}
