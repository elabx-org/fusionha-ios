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
                VStack(spacing: 12) {
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
                NavigationLink { SettingsWebPanel(slug: "instances") } label: { Text("+ Add connection") }
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
            message: mine ? "This app signs in with this token — revoking it signs this app out."
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

// MARK: Instance card

private struct InstanceCard: View {
    let instance: VirtualInstance
    let roots: [RootFolder]
    let revealedKey: String?
    let copied: String?
    let onToggle: (Bool) -> Void
    let onRemapRoot: (Int) -> Void
    let onReveal: () -> Void
    let onHide: () -> Void
    let onCopyKey: () -> Void
    let onCopyURL: () -> Void
    let onRegenerate: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var offeredRoots: [RootFolder] {
        guard let allowed = instance.allowedRootFolderIds, !allowed.isEmpty else { return roots }
        return roots.filter { allowed.contains($0.id) }
    }

    private var offered: (text: String, scoped: Bool) {
        guard let p = instance.allowedQualityProfileIds, let r = instance.allowedRootFolderIds else {
            return ("All profiles · all roots", false)
        }
        return ("\(p.count) profile\(p.count == 1 ? "" : "s") · \(r.count) root\(r.count == 1 ? "" : "s")", true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: instance.isRadarr ? "film" : "tv")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(instance.tier.color)
                    .frame(width: 40, height: 40)
                    .background(instance.tier.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(instance.tier.color.opacity(0.3)))
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(instance.instanceName).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(1)
                        HStack(spacing: 5) {
                            Circle().fill(instance.enabled ? Theme.done : Theme.dim).frame(width: 6, height: 6)
                            Text(instance.enabled ? "Enabled" : "Disabled")
                        }
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(instance.enabled ? Theme.done : Theme.mut)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background((instance.enabled ? Theme.done : Theme.dim).opacity(0.12), in: Capsule())
                    }
                    FetchFlow(spacing: 5, lineSpacing: 4) {
                        EditionChip(tier: instance.tier)
                        Text("·").foregroundStyle(Theme.dim)
                        Text(instance.kind == "movie" ? "Movies" : "Series")
                        if let scope = instance.scope, scope != "all" {
                            Text("·").foregroundStyle(Theme.dim)
                            FetchChip(text: scope == "anime" ? "Anime only" : "Non-anime", color: Theme.anime,
                                      border: Theme.anime.opacity(0.4))
                        }
                        Text("·").foregroundStyle(Theme.dim)
                        Text(instance.slug).font(.system(size: 11.5, design: .monospaced))
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.mut)
                }
                Spacer(minLength: 0)
                Toggle("Enable \(instance.instanceName)", isOn: Binding(get: { instance.enabled }, set: onToggle))
                    .labelsHidden().tint(Theme.indigo)
            }

            field("API key") {
                valuePill(revealedKey ?? String(repeating: "•", count: 28) + (instance.apiKeyLast4 ?? ""),
                          secret: revealedKey == nil, copiedNow: copied == "\(instance.id):key",
                          copyLabel: "Copy key for \(instance.instanceName)", onCopy: onCopyKey) {
                    FetchIconButton(systemName: revealedKey == nil ? "eye" : "eye.slash",
                                    label: revealedKey == nil ? "Reveal key for \(instance.instanceName)"
                                        : "Hide key for \(instance.instanceName)",
                                    action: revealedKey == nil ? onReveal : onHide)
                }
            }
            HStack(alignment: .top, spacing: 10) {
                field("Connect URL") {
                    valuePill("/\(instance.slug)", secret: false, copiedNow: copied == "\(instance.id):url",
                              copyLabel: "Copy connect URL for \(instance.instanceName)", onCopy: onCopyURL) { EmptyView() }
                }
                field("Root folder") {
                    Menu {
                        ForEach(offeredRoots) { root in
                            Button {
                                onRemapRoot(root.id)
                            } label: {
                                if root.id == instance.defaultRootFolderId {
                                    Label(root.path, systemImage: "checkmark")
                                } else {
                                    Text(root.path)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(roots.first { $0.id == instance.defaultRootFolderId }?.path ?? "Root folder")
                                .font(.system(size: 12, design: .monospaced))
                                .lineLimit(1).truncationMode(.middle)
                            Spacer(minLength: 2)
                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(Theme.txt)
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.line))
                    }
                    .accessibilityLabel("Root folder for \(instance.instanceName)")
                }
            }
            field("Offered to Overseerr") {
                Button(action: onEdit) {
                    HStack(spacing: 8) {
                        Circle().fill(offered.scoped ? Theme.miss : Theme.done).frame(width: 7, height: 7)
                        Text(offered.text).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.txt)
                        Spacer()
                        Image(systemName: "slider.horizontal.3").font(.system(size: 13)).foregroundStyle(Theme.mut)
                    }
                    .padding(.horizontal, 11)
                    .frame(height: 36)
                    .background((offered.scoped ? Theme.miss : Theme.done).opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.line))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Offer limits for \(instance.instanceName): \(offered.text)")
            }

            Rectangle().fill(Theme.line).frame(height: 1)
            HStack(spacing: 4) {
                Text(instance.isRadarr ? "Radarr" : "Sonarr").font(.system(size: 11.5)).foregroundStyle(Theme.dim)
                Spacer()
                Button(action: onRegenerate) { Label("Regenerate key", systemImage: "arrow.triangle.2.circlepath") }
                    .buttonStyle(.web())
                    .accessibilityLabel("Regenerate key for \(instance.instanceName)")
                FetchIconButton(systemName: "pencil", label: "Edit \(instance.instanceName)", action: onEdit)
                FetchIconButton(systemName: "trash", label: "Delete \(instance.instanceName)", danger: true, action: onDelete)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [instance.tier.color.opacity(0.08), .clear], startPoint: .topLeading, endPoint: .center),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
        .opacity(instance.enabled ? 1 : 0.75)
    }

    private func field<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased()).font(.system(size: 9.5, weight: .heavy)).tracking(0.6).foregroundStyle(Theme.dim)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func valuePill<A: View>(_ display: String, secret: Bool, copiedNow: Bool, copyLabel: String,
                                    onCopy: @escaping () -> Void, @ViewBuilder accessory: () -> A) -> some View {
        HStack(spacing: 0) {
            Text(display)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(secret ? Theme.mut : Theme.txt)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .padding(.leading, 10)
            Spacer(minLength: 4)
            accessory()
            FetchIconButton(systemName: copiedNow ? "checkmark" : "doc.on.doc", label: copyLabel,
                            tint: copiedNow ? Theme.done : nil, action: onCopy)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(height: 36)
        .background(Theme.bg, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.line))
    }
}

// MARK: Edit connection

/// The web's Edit connection dialog: display name, the locked type, the series
/// scope, and the offer-only limits (Everything / Only selected profiles + roots
/// with a default each).
private struct InstanceEditSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let instance: VirtualInstance
    let roots: [RootFolder]
    let profiles: [QualityProfile]
    let onSaved: () async -> Void

    @State private var name: String
    @State private var scope: String
    @State private var onlySelected: Bool
    @State private var profileIds: [Int]
    @State private var rootIds: [Int]
    @State private var defaultProfileId: Int?
    @State private var defaultRootId: Int?
    @State private var saving = false
    @State private var saveError: String?

    init(instance: VirtualInstance, roots: [RootFolder], profiles: [QualityProfile], onSaved: @escaping () async -> Void) {
        self.instance = instance
        self.roots = roots
        self.profiles = profiles
        self.onSaved = onSaved
        let scoped = instance.allowedQualityProfileIds != nil && instance.allowedRootFolderIds != nil
        _name = State(initialValue: instance.instanceName)
        _scope = State(initialValue: ["all", "anime", "non_anime"].contains(instance.scope ?? "") ? instance.scope! : "all")
        _onlySelected = State(initialValue: scoped)
        _profileIds = State(initialValue: scoped ? instance.allowedQualityProfileIds ?? [] : [])
        _rootIds = State(initialValue: scoped ? instance.allowedRootFolderIds ?? [] : [])
        _defaultProfileId = State(initialValue: instance.defaultQualityProfileId)
        _defaultRootId = State(initialValue: instance.defaultRootFolderId)
    }

    private var storedScope: String { ["all", "anime", "non_anime"].contains(instance.scope ?? "") ? instance.scope! : "all" }
    private var scopeApplies: Bool { instance.kind == "series" || storedScope != "all" }

    /// Profiles that fit this flavor (movie profiles for Radarr, series/anime for Sonarr).
    private var flavorProfiles: [QualityProfile] {
        profiles.filter { p in
            guard let kind = p.mediaKind else { return true }
            return instance.isRadarr ? kind == "movie" : kind != "movie"
        }
    }

    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (!onlySelected || (!profileIds.isEmpty && !rootIds.isEmpty))
    }

    private var footnote: (String, Bool) {
        if !onlySelected { return ("Offering everything (unrestricted)", false) }
        if profileIds.isEmpty || rootIds.isEmpty { return ("Select at least one profile and one root", true) }
        return ("Offering \(profileIds.count) profile\(profileIds.count == 1 ? "" : "s") · \(rootIds.count) root\(rootIds.count == 1 ? "" : "s")", false)
    }

    var body: some View {
        FetchFormSheet(title: "Edit connection",
                       subtitle: "\(instance.instanceName) · \(instance.tier.chipLabel) · \(instance.kind == "movie" ? "Movies" : "Series")",
                       saveLabel: "Save changes", canSave: valid, saving: saving,
                       onCancel: { dismiss() }, onSave: save) {
            SettingsSection {
                FetchTextRow(label: "Display name", text: $name)
                LabeledContent {
                    Text("\(instance.flavor.lowercased()) · \(instance.kind) · \(instance.tier.rawValue) · /\(instance.slug)")
                        .font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.mut)
                        .multilineTextAlignment(.trailing)
                } label: {
                    FieldLabel(label: "Type", description: "fixed after creation")
                }
                if scopeApplies {
                    Picker(selection: $scope) {
                        Text("All series").tag("all")
                        Text("Anime only").tag("anime")
                        Text("Non-anime").tag("non_anime")
                    } label: {
                        FieldLabel(label: "Scope",
                                   description: "Changing this also re-derives the kind-scope of every indexer Prowlarr has synced into this connection.")
                    }
                    .pickerStyle(.menu).tint(Theme.mut)
                }
            }
            Section {
                Picker("Offered to Overseerr", selection: $onlySelected) {
                    Text("Everything").tag(false)
                    Text("Only selected").tag(true)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } header: {
                Text("Offered to Overseerr")
            } footer: {
                Text(footnote.0).foregroundStyle(footnote.1 ? Theme.miss : Theme.mut)
            }
            if onlySelected {
                limitSection("Quality profiles", rows: flavorProfiles.map { ($0.id, $0.name) },
                             selected: $profileIds, defaultId: $defaultProfileId)
                limitSection("Root folders", rows: roots.map { ($0.id, $0.path) },
                             selected: $rootIds, defaultId: $defaultRootId)
            }
            if let saveError {
                Section { Label(saveError, systemImage: "xmark").font(.system(size: 12)).foregroundStyle(Theme.danger) }
                    .listRowBackground(Theme.card)
            }
        }
    }

    private func limitSection(_ title: String, rows: [(Int, String)], selected: Binding<[Int]>,
                              defaultId: Binding<Int?>) -> some View {
        let effective = effectiveDefault(rows: rows, selected: selected.wrappedValue, current: defaultId.wrappedValue)
        return SettingsSection("\(title) · \(selected.wrappedValue.count) / \(rows.count)") {
            HStack {
                Button("Select all") { selected.wrappedValue = rows.map(\.0) }.buttonStyle(.web(.ghost))
                Button("Clear") { selected.wrappedValue = [] }.buttonStyle(.web(.ghost))
                Spacer()
            }
            ForEach(rows, id: \.0) { id, label in
                let isOn = selected.wrappedValue.contains(id)
                HStack(spacing: 10) {
                    Button {
                        if isOn { selected.wrappedValue.removeAll { $0 == id } } else { selected.wrappedValue.append(id) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: isOn ? "checkmark.square.fill" : "square")
                                .foregroundStyle(isOn ? Theme.cyan : Theme.dim)
                            Text(label).font(.system(size: 13.5)).foregroundStyle(Theme.txt).lineLimit(1)
                            Spacer(minLength: 4)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if isOn {
                        if effective == id {
                            FetchPill(text: "Default", tone: .ok)
                        } else {
                            Button("Make default") { defaultId.wrappedValue = id }
                                .font(.system(size: 11, weight: .semibold))
                                .buttonStyle(.plain)
                                .foregroundStyle(Theme.mut)
                        }
                    }
                }
            }
        }
    }

    /// The current default when still selected, else the first selected row.
    private func effectiveDefault(rows: [(Int, String)], selected: [Int], current: Int?) -> Int? {
        if selected.isEmpty { return nil }
        if let current, selected.contains(current) { return current }
        return rows.first { selected.contains($0.0) }?.0 ?? selected.first
    }

    private func save() {
        guard let client = model.client, valid else { return }
        var body: [String: SettingsJSON] = ["instance_name": .string(name.trimmingCharacters(in: .whitespaces))]
        if onlySelected {
            let profileRows = flavorProfiles.map { ($0.id, $0.name) }
            let rootRows = roots.map { ($0.id, $0.path) }
            body["allowed_quality_profile_ids"] = .ints(profileIds)
            body["allowed_root_folder_ids"] = .ints(rootIds)
            body["default_quality_profile_id"] = .optional(effectiveDefault(rows: profileRows, selected: profileIds, current: defaultProfileId))
            body["default_root_folder_id"] = .optional(effectiveDefault(rows: rootRows, selected: rootIds, current: defaultRootId))
        } else {
            body["allowed_quality_profile_ids"] = .null
            body["allowed_root_folder_ids"] = .null
            body["default_quality_profile_id"] = .optional(instance.defaultQualityProfileId)
            body["default_root_folder_id"] = .optional(instance.defaultRootFolderId)
        }
        // Omit scope unless it changed: an explicit write would clobber it.
        if scopeApplies && scope != storedScope { body["scope"] = .string(scope) }
        saving = true
        saveError = nil
        Task {
            do {
                try await client.updateInstance(id: instance.id, .object(body))
                await onSaved()
                dismiss()
            } catch { saveError = error.settingsMessage }
            saving = false
        }
    }
}

// MARK: Mint token

private struct MintTokenSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let onMinted: () async -> Void
    @State private var name = ""
    @State private var expires = false
    @State private var expiresOn = Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now
    @State private var minted: String?
    @State private var copied = false
    @State private var saving = false
    @State private var saveError: String?

    var body: some View {
        FetchFormSheet(title: "Mint API token",
                       subtitle: minted == nil ? "A personal token for scripts or external tools to authenticate directly against `/api/v1`." : nil,
                       saveLabel: minted == nil ? "Mint token" : "Done",
                       canSave: minted != nil || !name.trimmingCharacters(in: .whitespaces).isEmpty,
                       saving: saving,
                       onCancel: { dismiss() },
                       onSave: { if minted != nil { dismiss() } else { mint() } }) {
            if let minted {
                SettingsSection(footer: "This is the only time this token is shown — copy it now. If it's lost, revoke it here and mint a new one.") {
                    Text(minted)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Theme.txt)
                        .textSelection(.enabled)
                    Button(copied ? "Copied" : "Copy") {
                        UIPasteboard.general.string = minted
                        copied = true
                    }
                    .buttonStyle(.web())
                    .accessibilityLabel("Copy minted token")
                }
            } else {
                SettingsSection(footer: "Leave the expiry off for a token that never expires.") {
                    FetchTextRow(label: "Name", text: $name, prompt: "CI script")
                    Toggle(isOn: $expires) { FieldLabel(label: "Expires") }.tint(Theme.indigo)
                    if expires {
                        DatePicker("Expires on", selection: $expiresOn, in: Date.now..., displayedComponents: .date)
                            .tint(Theme.cyan)
                    }
                }
                if let saveError {
                    Section { Label(saveError, systemImage: "xmark").font(.system(size: 12)).foregroundStyle(Theme.danger) }
                        .listRowBackground(Theme.card)
                }
            }
        }
        .interactiveDismissDisabled(minted != nil)
    }

    private func mint() {
        guard let client = model.client else { return }
        var expiresAt: String?
        if expires {
            let end = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: expiresOn) ?? expiresOn
            expiresAt = ISO8601DateFormatter().string(from: end)
        }
        saving = true
        saveError = nil
        Task {
            do {
                minted = try await client.mintApiToken(name: name.trimmingCharacters(in: .whitespaces), expiresAt: expiresAt).token
                await onMinted()
            } catch { saveError = error.settingsMessage }
            saving = false
        }
    }
}
