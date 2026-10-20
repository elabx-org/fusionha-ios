import SwiftUI
import UIKit
import FusionhaKit

/// Settings → Connections (`InstancesPanel.tsx` + `ApiTokensPanel.tsx`): the
/// virtual Radarr/Sonarr instances Overseerr and Prowlarr add (enable, masked key
/// with reveal / copy / regenerate, connect URL, default root, offer limits, edit,
/// delete) and this user's personal API tokens (mint, revoke).
struct ConnectionsPanel: View {
    @Environment(AppModel.self) private var model
    @State private var instances: [VirtualInstance] = []
    @State private var roots: [RootFolder] = []
    @State private var profiles: [QualityProfile] = []
    @State private var tokens: [ApiTokenInfo] = []
    @State private var loaded = false
    @State private var error: String?
    @State private var revealed: [Int: String] = [:]
    @State private var copied: String?
    @State private var editing: VirtualInstance?
    @State private var minting = false
    @State private var adding = false
    @State private var toaster = FetchToaster()
    @State private var confirm: FetchConfirm?

    private func can(_ permission: String) -> Bool {
        guard let me = model.me else { return true }
        return me.isAdmin || (me.permissions ?? []).contains(permission)
    }

    var body: some View {
        FetchingPage(slug: "instances", toaster: toaster, confirm: $confirm, refresh: load) {
            if can("connections.manage") {
                FetchSectionHead(title: "Virtual instances", count: instances.count,
                                 description: "External tools authenticate with each instance’s own API key.")
                if !loaded || error != nil { FetchLoading(error: error) }
                // Web `InstancesPanel` `.grid`: auto-fill minmax(430, 1fr).
                AutoFillGrid(minItemWidth: 430, spacing: 12) {
                    ForEach(Array(instances.enumerated()), id: \.element.id) { index, instance in
                        InstanceCard(instance: instance, roots: roots, revealedKey: revealed[instance.id],
                                     copied: copied,
                                     onToggle: { toggle(instance, $0) },
                                     onRemapRoot: { remapRoot(instance, $0) },
                                     onReveal: { reveal(instance) },
                                     onHide: { revealed[instance.id] = nil },
                                     onCopyKey: { copyKey(instance) },
                                     onCopyURL: { copy("/\(instance.slug)", field: "\(instance.id):url", message: "Connect URL copied") },
                                     onRegenerate: { askRegenerate(instance) },
                                     onEdit: { editing = instance },
                                     onDelete: { askDelete(instance) })
                            .fetchReveal(index)
                    }
                }
                if loaded, instances.isEmpty, error == nil {
                    FetchEmpty(text: "No connections yet — add one for Overseerr and Prowlarr to connect to.")
                }
                Button("+ Add connection") { adding = true }
                    .buttonStyle(.web())
                    .padding(.top, 14)
            } else {
                FetchEmpty(text: "You do not have permission to manage connections.")
            }

            Color.clear.frame(height: 28)

            if can("tokens.manage.self") {
                tokensSection
            } else {
                FetchEmpty(text: "You do not have permission to manage API tokens.")
            }
        }
        .task { await load() }
        .sheet(item: $editing) { instance in
            InstanceEditSheet(instance: instance, roots: roots, profiles: profiles) { await load() }
        }
        .sheet(isPresented: $adding) {
            InstanceEditSheet(instance: nil, roots: roots, profiles: profiles) { await load() }
        }
        .sheet(isPresented: $minting) {
            MintTokenSheet { await loadTokens() }
        }
    }

    // MARK: Tokens

    private var tokensSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            FetchSectionHead(title: "API tokens", count: tokens.count,
                             description: "Personal tokens for scripts & external tools — scoped to your role.")
            VStack(spacing: 12) {
                ForEach(Array(tokens.enumerated()), id: \.element.id) { index, token in
                    HStack(alignment: .center, spacing: 14) {
                        FetchIconTile(systemName: "key")
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(token.name).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(1)
                                if token.id == model.credentials?.tokenId { FetchPill(text: "This app", tone: .accent) }
                            }
                            (Text("\(token.tokenPrefix)…").font(.system(size: 12, design: .monospaced))
                                + Text(" · \(token.lastUsedAt.map { "used \(FetchFormat.ago($0))" } ?? "never used")"))
                                .font(.system(size: 12)).foregroundStyle(Theme.mut).lineLimit(1)
                            Text(token.expiresAt.flatMap { FetchFormat.date($0) }
                                    .map { "Expires \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "Never expires")
                                .font(.system(size: 12)).foregroundStyle(Theme.mut)
                        }
                        Spacer(minLength: 0)
                        FetchIconButton(systemName: "trash", label: "Revoke \(token.name)", danger: true) { askRevoke(token) }
                    }
                    .fetchCard()
                    .fetchReveal(index)
                }
            }
            if tokens.isEmpty && loaded {
                FetchEmpty(text: "No API tokens yet — mint one for scripts or external tools that need native `/api/v1` access.")
            }
            Button("+ Mint token") { minting = true }.buttonStyle(.web()).padding(.top, 14)
        }
    }

    // MARK: Actions

    private func load() async {
        guard let client = model.client else { return }
        if can("connections.manage") {
            do {
                async let list = client.instances()
                async let r = try? client.rootFolders()
                async let p = try? client.qualityProfiles()
                instances = try await list
                roots = await r ?? []
                profiles = await p ?? []
                error = nil
            } catch {
                self.error = error.settingsMessage
            }
        }
        await loadTokens()
        loaded = true
    }

    private func loadTokens() async {
        guard let client = model.client, can("tokens.manage.self") else { return }
        tokens = (try? await client.apiTokens()) ?? tokens
    }

    private func patch(_ instance: VirtualInstance, _ body: SettingsJSON, title: String) {
        guard let client = model.client else { return }
        Task {
            do {
                try await client.updateInstance(id: instance.id, body)
                await load()
            } catch { toaster.error(error, title: title) }
        }
    }

    private func toggle(_ instance: VirtualInstance, _ on: Bool) {
        patch(instance, ["enabled": .bool(on)], title: "Could not update the connection")
    }

    private func remapRoot(_ instance: VirtualInstance, _ rootId: Int) {
        patch(instance, ["default_root_folder_id": .int(rootId)], title: "Could not change the root folder")
    }

    private func reveal(_ instance: VirtualInstance, then: ((String) -> Void)? = nil) {
        guard let client = model.client else { return }
        Task {
            do {
                let key = try await client.revealInstanceKey(id: instance.id).apiKey
                revealed[instance.id] = key
                then?(key)
            } catch { toaster.error(error) }
        }
    }

    private func copyKey(_ instance: VirtualInstance) {
        if let key = revealed[instance.id] {
            copy(key, field: "\(instance.id):key", message: "API key copied")
        } else {
            reveal(instance) { copy($0, field: "\(instance.id):key", message: "API key copied") }
        }
    }

    private func copy(_ text: String, field: String, message: String) {
        UIPasteboard.general.string = text
        copied = field
        toaster.show(message)
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            if copied == field { copied = nil }
        }
    }

    private func askRegenerate(_ instance: VirtualInstance) {
        confirm = FetchConfirm(
            title: "Regenerate the key for \(instance.instanceName)?",
            message: "Overseerr/Prowlarr using the current key stop authenticating until you paste the new one.",
            action: "Regenerate") {
            Task {
                guard let client = model.client else { return }
                do {
                    let key = try await client.regenerateInstanceKey(id: instance.id).apiKey
                    await load()
                    revealed[instance.id] = key
                } catch { toaster.error(error) }
            }
        }
    }

    private func askDelete(_ instance: VirtualInstance) {
        confirm = FetchConfirm(
            title: "Delete the “\(instance.instanceName)” connection?",
            message: "Overseerr/Prowlarr configured against /\(instance.slug) will stop working.") {
            Task {
                guard let client = model.client else { return }
                do {
                    try await client.deleteInstance(id: instance.id)
                    await load()
                } catch { toaster.error(error, title: "Could not delete connection") }
            }
        }
    }

    private func askRevoke(_ token: ApiTokenInfo) {
        let mine = token.id == model.credentials?.tokenId
        confirm = FetchConfirm(
            title: "Revoke the “\(token.name)” token?",
            message: mine ? "This app signs in with this token. Revoking it signs this app out."
                : "Anything using it will stop authenticating immediately.",
            action: "Revoke") {
            Task {
                guard let client = model.client else { return }
                do {
                    try await client.revokeApiToken(id: token.id)
                    await loadTokens()
                } catch { toaster.error(error, title: "Could not revoke token") }
            }
        }
    }
}
