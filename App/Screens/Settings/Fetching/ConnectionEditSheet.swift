import SwiftUI
import FusionhaKit

// MARK: Add / edit connection

/// The web's Add connection and Edit connection dialogs in one sheet. Edit:
/// display name, the locked type, the series scope and the offer-only limits.
/// Add (`instance == nil`): name, an auto-derived slug, flavor, kind, tier, the
/// series scope (Anime only suggests `Sonarr-Anime-HD`), then the limits.
struct InstanceEditSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let instance: VirtualInstance?
    let roots: [RootFolder]
    let profiles: [QualityProfile]
    let onSaved: () async -> Void

    @State private var name: String
    @State private var slug = ""
    @State private var nameTouched = false
    @State private var slugTouched = false
    @State private var flavor = "RADARR"
    @State private var kind = "movie"
    @State private var tier: QualityTier = .hd
    @State private var scope: String
    @State private var onlySelected: Bool
    @State private var profileIds: [Int]
    @State private var rootIds: [Int]
    @State private var defaultProfileId: Int?
    @State private var defaultRootId: Int?
    @State private var saving = false
    @State private var saveError: String?

    init(instance: VirtualInstance?, roots: [RootFolder], profiles: [QualityProfile], onSaved: @escaping () async -> Void) {
        self.instance = instance
        self.roots = roots
        self.profiles = profiles
        self.onSaved = onSaved
        let scoped = instance?.allowedQualityProfileIds != nil && instance?.allowedRootFolderIds != nil
        _name = State(initialValue: instance?.instanceName ?? "")
        _scope = State(initialValue: Self.normalised(instance?.scope))
        _onlySelected = State(initialValue: scoped)
        _profileIds = State(initialValue: scoped ? instance?.allowedQualityProfileIds ?? [] : [])
        _rootIds = State(initialValue: scoped ? instance?.allowedRootFolderIds ?? [] : [])
        _defaultProfileId = State(initialValue: instance?.defaultQualityProfileId)
        _defaultRootId = State(initialValue: instance?.defaultRootFolderId)
    }

    private static func normalised(_ scope: String?) -> String {
        ConnectionCreate.scopes.contains { $0.value == scope } ? scope ?? "all" : "all"
    }

    private var isRadarr: Bool { instance?.isRadarr ?? (flavor == "RADARR") }
    private var storedScope: String { Self.normalised(instance?.scope) }
    private var scopeApplies: Bool {
        guard let instance else { return ConnectionCreate.scopeApplies(kind: kind) }
        return ConnectionCreate.scopeApplies(kind: instance.kind) || storedScope != "all"
    }

    /// Profiles that fit this flavor (movie profiles for Radarr, series/anime for Sonarr).
    private var profileRows: [(Int, String)] {
        profiles.filter { p in
            guard let kind = p.mediaKind else { return true }
            return isRadarr ? kind == "movie" : kind != "movie"
        }
        .map { ($0.id, $0.name) }
    }

    private var rootRows: [(Int, String)] { roots.map { ($0.id, $0.path) } }

    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && (instance != nil || !slug.trimmingCharacters(in: .whitespaces).isEmpty)
            && ConnectionLimitsSection.valid(onlySelected: onlySelected, profileIds: profileIds, rootIds: rootIds)
    }

    private var subtitle: String {
        guard let instance else { return "A new virtual arr instance Overseerr/Prowlarr can connect to." }
        return "\(instance.instanceName) · \(instance.tier.chipLabel) · \(instance.kind == "movie" ? "Movies" : "Series")"
    }

    var body: some View {
        FetchFormSheet(title: instance == nil ? "Add connection" : "Edit connection", subtitle: subtitle,
                       saveLabel: instance == nil ? "Add connection" : "Save changes", canSave: valid, saving: saving,
                       onCancel: { dismiss() }, onSave: save) {
            SettingsSection {
                if let instance {
                    FetchTextRow(label: "Display name", text: $name)
                    LabeledContent {
                        Text("\(instance.flavor.lowercased()) · \(instance.kind) · \(instance.tier.rawValue) · /\(instance.slug)")
                            .font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.mut)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        FieldLabel(label: "Type", description: "fixed after creation")
                    }
                } else {
                    identityRows
                }
                if scopeApplies { scopePicker }
            }
            ConnectionLimitsSection(onlySelected: $onlySelected, profileRows: profileRows, rootRows: rootRows,
                                    profileIds: $profileIds, rootIds: $rootIds,
                                    defaultProfileId: $defaultProfileId, defaultRootId: $defaultRootId)
            if let saveError {
                Section { Label(saveError, systemImage: "xmark").font(.system(size: 12)).foregroundStyle(Theme.danger) }
                    .listRowBackground(Theme.card)
            }
        }
    }

    @ViewBuilder
    private var identityRows: some View {
        FetchTextRow(label: "Name", text: Binding(get: { name }, set: { nameChanged($0) }), prompt: "Radarr-HD")
        FetchTextRow(label: "Slug", text: Binding(get: { slug }, set: { slugTouched = true; slug = ConnectionCreate.slugify($0) }),
                     prompt: "radarr-hd", mono: true,
                     hint: "Base URL will be /\(slug.isEmpty ? "…" : slug)")
        Picker(selection: Binding(get: { flavor }, set: { flavorChanged($0) })) {
            Text("Radarr").tag("RADARR")
            Text("Sonarr").tag("SONARR")
        } label: { FieldLabel(label: "Flavor") }
            .pickerStyle(.menu).tint(Theme.mut)
        Picker(selection: Binding(get: { kind }, set: { kindChanged($0) })) {
            Text("Movie").tag("movie")
            Text("Series").tag("series")
        } label: { FieldLabel(label: "Kind") }
            .pickerStyle(.menu).tint(Theme.mut)
        Picker(selection: Binding(get: { tier }, set: { tier = $0; suggestAnime(scope: scope, tier: $0) })) {
            Text(QualityTier.hd.chipLabel).tag(QualityTier.hd)
            Text(QualityTier.uhd.chipLabel).tag(QualityTier.uhd)
        } label: { FieldLabel(label: "Tier") }
            .pickerStyle(.menu).tint(Theme.mut)
    }

    private var scopePicker: some View {
        Picker(selection: Binding(get: { scope }, set: { scope = $0; suggestAnime(scope: $0, tier: tier) })) {
            Text("All series").tag("all")
            Text("Anime only").tag("anime")
            Text("Non-anime").tag("non_anime")
        } label: {
            FieldLabel(label: "Scope",
                       description: instance == nil
                           ? "Which series this connection serves. Point Overseerr’s anime service (and Prowlarr’s anime indexers) at an anime-only one."
                           : "Changing this also re-derives the kind-scope of every indexer Prowlarr has synced into this connection.")
        }
        .pickerStyle(.menu).tint(Theme.mut)
    }

    // MARK: Add-form rules (web `AddConnectionDialog`)

    private func nameChanged(_ value: String) {
        nameTouched = true
        name = value
        if !slugTouched { slug = ConnectionCreate.slugify(value) }
    }

    private func kindChanged(_ next: String) {
        kind = next
        if !ConnectionCreate.scopeApplies(kind: next) { scope = "all" }
    }

    private func flavorChanged(_ next: String) {
        flavor = next
        // A selection made for the old flavor may not fit the new one.
        onlySelected = false
        profileIds = []
        rootIds = []
    }

    /// Anime only fills the suggested identity into untouched fields.
    private func suggestAnime(scope: String, tier: QualityTier) {
        guard instance == nil, scope == "anime" else { return }
        let suggested = ConnectionCreate.animeSuggestion(tier: tier)
        if !nameTouched {
            name = suggested.name
            if !slugTouched { slug = suggested.slug }
        } else if !slugTouched {
            slug = ConnectionCreate.slugify(name)
        }
    }

    private func save() {
        guard let client = model.client, valid else { return }
        let limits = ConnectionLimitsSection.payload(
            onlySelected: onlySelected, profileRows: profileRows, rootRows: rootRows,
            profileIds: profileIds, rootIds: rootIds, defaultProfileId: defaultProfileId, defaultRootId: defaultRootId,
            fallback: (instance?.defaultQualityProfileId, instance?.defaultRootFolderId))
        saving = true
        saveError = nil
        Task {
            do {
                if let instance {
                    var body = limits
                    body["instance_name"] = .string(name.trimmingCharacters(in: .whitespaces))
                    // Omit scope unless it changed: an explicit write would clobber it.
                    if scopeApplies && scope != storedScope { body["scope"] = .string(scope) }
                    try await client.updateInstance(id: instance.id, .object(body))
                } else {
                    try await client.createInstance(ConnectionCreate.body(
                        name: name, slug: slug, flavor: flavor, kind: kind, tier: tier, scope: scope, limits: limits))
                }
                await onSaved()
                dismiss()
            } catch { saveError = error.settingsMessage }
            saving = false
        }
    }
}
