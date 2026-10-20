import SwiftUI
import FusionhaKit

/// Settings › Access › Sign-in methods (web `SignInMethodsPanel` +
/// `TrustedProxiesCard`): the server-wide providers people sign in with
/// (fusionha's own password, Plex, OpenID Connect planned) and the trusted
/// reverse proxies. Needs Manage settings or full admin.
struct SignInMethodsSettingsPanel: View {
    @Environment(AppModel.self) private var model
    @State private var toaster = FetchToaster()

    private var allowed: Bool {
        guard let me = model.me else { return true }
        let perms = me.permissions ?? []
        return me.isAdmin || perms.contains("settings.manage") || perms.contains("system.admin")
    }

    var body: some View {
        SettingsForm(slug: "signin") {
            if !allowed {
                SettingsLoadingRow(error: "You do not have permission to manage sign-in methods.")
            } else {
                SignInLocalLoginSection(toaster: toaster)
                SignInPlexSection(toaster: toaster)
                SignInOidcPlannedSection()
                if model.me?.isAdmin != false { TrustedProxiesSection() }
            }
        }
        .fetchToasts(toaster)
    }
}

/// `PUT /api/v1/settings` awaited (unlike `SettingsStore.save`), so a guarded
/// change can report the server's own refusal; the store is reloaded after.
@MainActor
enum SignInSettings {
    static func put(_ diff: [String: JSONValue], store: SettingsStore) async throws {
        guard let client = store.client else { return }
        _ = try await client.json("PUT", "/api/v1/settings", body: .object(diff))
        await store.load()
    }
}

/// A provider card's head: glyph, title, status pill and description.
struct SignInProviderHeader: View {
    let symbol: String
    let tint: Color
    let title: String
    let pill: String
    let on: Bool
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt)
                    SettingsStatusPill(text: pill, color: on ? Theme.done : Theme.dim)
                }
                Text(description).font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 6)
    }
}

/// The built-in username / password provider. Turning it off confirms first;
/// the server refuses unless an external provider can admit an admin.
private struct SignInLocalLoginSection: View {
    let toaster: FetchToaster
    @Environment(SettingsStore.self) private var store
    @State private var configuring = false
    @State private var confirming = false
    @State private var pending = false

    private var on: Bool { store.bool("local_login_enabled", true) }

    var body: some View {
        SettingsSection {
            SignInProviderHeader(symbol: "person.badge.key", tint: Theme.i2, title: "fusionha",
                                 pill: on ? "On" : "Off", on: on,
                                 description: "Built-in username & password accounts, managed under Users. Turn it off to require an external provider — guarded so you can never lock yourself out.")
            Toggle("Enable fusionha sign-in", isOn: Binding(get: { on }, set: { toggle($0) }))
                .tint(Theme.indigo)
                .disabled(pending || !store.loaded)
                .settingsField("Enable fusionha sign-in")
            Button("Configure", systemImage: "pencil") { configuring = true }
        }
        .sheet(isPresented: $configuring) {
            SignInLocalLoginSheet(on: on, pending: pending, onEnable: { toggle(true) }, onDisable: { await disable() })
        }
        .signInDisableConfirm(isPresented: $confirming) { await disable() }
    }

    private func toggle(_ next: Bool) {
        if !next { confirming = true; return }
        Task {
            pending = true
            defer { pending = false }
            do {
                try await SignInSettings.put(["local_login_enabled": .bool(true)], store: store)
            } catch {
                toaster.show(error.settingsMessage, title: "Could not enable password sign-in", tone: .error)
            }
        }
    }

    private func disable() async {
        pending = true
        defer { pending = false }
        do {
            try await SignInSettings.put(["local_login_enabled": .bool(false)], store: store)
            toaster.show("People now sign in with an external provider only.", title: "Password sign-in disabled")
        } catch {
            toaster.show(error.settingsMessage, title: "Could not disable password sign-in", tone: .error)
        }
    }
}

/// Configure the built-in sign-in (web `LocalLoginConfigDialog`).
private struct SignInLocalLoginSheet: View {
    let on: Bool
    let pending: Bool
    let onEnable: () -> Void
    let onDisable: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsPush) private var push
    @State private var confirming = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("The built-in username & password sign-in — the account you set up fusionha with. Accounts are created and managed under Users.")
                        .foregroundStyle(Theme.mut)
                }
                Section {
                    Toggle(isOn: Binding(get: { on }, set: { if $0 { onEnable() } else { confirming = true } })) {
                        FieldLabel(label: "Allow username & password sign-in",
                                   description: "Turn off to require an external provider (e.g. Plex). Refused unless a provider can admit an admin — so you can never lock yourself out.")
                    }
                    .tint(Theme.indigo)
                    .disabled(pending)
                }
                Section {
                    FieldLabel(label: "Accounts",
                               description: "Create, disable, or set passwords for accounts under Users. New accounts are admin-created — there is no open self-registration.")
                    Button("Manage users", systemImage: "person.2") { dismiss(); push("access") }
                }
                Section("If you get locked out") {
                    Text("Set `FUSIONHA_FORCE_LOCAL_LOGIN=1` and restart to force the password form back on — no DB or API access needed. Or re-enable it via the API with your app key (`PUT /api/v1/settings`). Existing signed-in sessions keep working either way.")
                        .font(.footnote)
                        .foregroundStyle(Theme.txt)
                        .listRowBackground(Theme.i2.opacity(0.10))
                }
            }
            .navigationTitle("fusionha sign-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { SheetDoneButton { dismiss() } } }
            .closeOnlyBars()
            .signInDisableConfirm(isPresented: $confirming) { await onDisable() }
        }
    }
}

extension View {
    /// Confirms turning off password sign-in, spelling out the recovery paths.
    func signInDisableConfirm(isPresented: Binding<Bool>, perform: @escaping () async -> Void) -> some View {
        confirmationDialog("Disable username & password sign-in?", isPresented: isPresented, titleVisibility: .visible) {
            Button("Disable password sign-in", role: .destructive) { Task { await perform() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("People will then sign in only through an external provider (e.g. Plex). fusionha checks first that a provider is enabled, configured, and can admit an admin — otherwise this is refused. If you ever get locked out: set FUSIONHA_FORCE_LOCAL_LOGIN=1 and restart, or re-enable this via the API with your app key (PUT /api/v1/settings). Existing signed-in sessions keep working either way.")
        }
    }
}

/// A placeholder for a future generic OIDC provider (Authentik, Authelia, Google, …).
private struct SignInOidcPlannedSection: View {
    var body: some View {
        SettingsSection(footer: "More sign-in providers (SAML, additional OIDC) are planned.") {
            SignInProviderHeader(symbol: "person.badge.shield.checkmark", tint: Theme.dim, title: "OpenID Connect",
                                 pill: "Planned", on: false,
                                 description: "Generic OIDC (Authentik, Authelia, Google, …) — a future sign-in method.")
            Button("Configure", systemImage: "pencil") {}.disabled(true)
        }
    }
}
