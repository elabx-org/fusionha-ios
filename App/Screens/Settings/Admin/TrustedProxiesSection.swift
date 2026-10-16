import SwiftUI
import FusionhaKit

/// Sign-in methods › Trusted reverse proxies (web `TrustedProxiesCard`): the
/// CIDRs allowed to set the client address (`X-Forwarded-For` / `X-Real-IP`).
/// The sign-in limiter keys on that address. Admin only; one list, saved on Save.
struct TrustedProxiesSection: View {
    @Environment(AppModel.self) private var model
    @State private var saved: [String]?
    @State private var text = ""
    @State private var loadFailed = false
    @State private var saving = false
    @State private var message: String?
    @State private var savedOK = false

    private var entries: [String] { TrustedProxies.parse(text) }
    private var problems: [String] { entries.compactMap { TrustedProxies.problem($0) } }
    private var dirty: Bool { saved != nil && entries != saved }

    var body: some View {
        Section {
            Text("Behind Traefik, nginx, Caddy or another proxy, list its network here so fusionha reads the real client address from `X-Forwarded-For`. Sign-in limits use that address. Leave it empty when nothing sits in front of fusionha: forwarded headers are then ignored, so no one can fake their address.")
                .font(.footnote)
                .foregroundStyle(Theme.mut)
            TextField("IP addresses or CIDRs, one per line", text: $text,
                      prompt: Text("172.18.0.0/16\n10.0.0.1"), axis: .vertical)
                .font(.system(size: 13, design: .monospaced))
                .lineLimit(3...8)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .disabled(saved == nil)
                .onChange(of: text) { message = nil; if entries != saved { savedOK = false } }
                .settingsField("Trusted reverse proxies")
            Button(saving ? "Saving…" : (savedOK ? "Saved" : "Save")) { Task { await save() } }
                .disabled(!dirty || !problems.isEmpty || saving)
        } header: {
            Text("Trusted reverse proxies")
                .font(.system(size: 15, weight: .semibold))
                .textCase(nil)
                .foregroundStyle(Theme.mut)
        } footer: {
            footer
        }
        .listRowBackground(Theme.card)
        .task { await load() }
    }

    @ViewBuilder
    private var footer: some View {
        if loadFailed {
            Text("Couldn’t load the list. Refresh to try again.").foregroundStyle(Theme.danger)
        } else if !problems.isEmpty {
            Text(problems.joined(separator: "\n")).foregroundStyle(Theme.danger)
        } else if let message {
            Text(message).foregroundStyle(Theme.danger)
        } else {
            Text("IPv4 or IPv6, for example your Docker network. Applies at once, no restart.")
        }
    }

    private func load() async {
        guard let client = model.client, saved == nil else { return }
        do {
            let cidrs = try await client.trustedProxies()
            saved = cidrs
            text = cidrs.joined(separator: "\n")
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }

    private func save() async {
        guard let client = model.client, dirty, problems.isEmpty else { return }
        saving = true
        defer { saving = false }
        do {
            let cidrs = try await client.updateTrustedProxies(entries)
            saved = cidrs
            text = cidrs.joined(separator: "\n")
            savedOK = true
        } catch {
            message = TrustedProxies.saveError(error)
        }
    }
}
