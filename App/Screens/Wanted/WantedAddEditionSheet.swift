import SwiftUI
import FusionhaKit

// MARK: - Add edition (AddEditionDialog, preset UHD·4K)

struct WantedAddEditionSheet: View {
    let item: FourKAvailableItem
    let onAdded: () -> Void
    let onCancel: () -> Void
    @Environment(AppModel.self) private var model
    @State private var tier: QualityTier = .uhd
    @State private var roots: [RootFolder] = []
    @State private var profiles: [QualityProfile] = []
    @State private var defaults: [AddDefaultSlot] = []
    @State private var rootId = 0
    @State private var profileId = 0
    @State private var monitored = true
    @State private var searchNow = true
    @State private var saving = false
    @State private var error: String?

    private var resolvedKind: String { item.isAnime ? "anime" : item.kind.rawValue }

    private var kindProfiles: [QualityProfile] {
        let matching = profiles.filter { p in
            guard let k = p.mediaKind?.lowercased(), k != "any" else { return true }
            return k == resolvedKind || (resolvedKind == "anime" && k == "series")
        }
        return matching.isEmpty ? profiles : matching
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tier", selection: $tier) {
                        Text(QualityTier.hd.chipLabel).tag(QualityTier.hd)
                        Text(QualityTier.uhd.chipLabel).tag(QualityTier.uhd)
                    }
                    Picker("Root folder", selection: $rootId) {
                        if rootId == 0 { Text("—").tag(0) }
                        ForEach(roots) { r in Text(r.path).font(.system(.body, design: .monospaced)).tag(r.id) }
                    }
                    Picker("Quality profile", selection: $profileId) {
                        if profileId == 0 { Text("—").tag(0) }
                        ForEach(kindProfiles) { p in Text(p.name).tag(p.id) }
                    }
                } footer: {
                    Text("\(item.title) · a new tier + edition copy, tracked independently")
                }
                Section {
                    Toggle(monitored ? "Monitored" : "Unmonitored", isOn: $monitored)
                    Toggle("Search for releases now", isOn: $searchNow)
                }
                if let error {
                    Section { Text(error).foregroundStyle(Theme.danger).font(.system(size: 13)) }
                }
            }
            .tint(Theme.indigo)
            .scrollContentBackground(.hidden)
            .background(Theme.panel)
            .navigationTitle("Add a version")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton(action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if saving { ProgressView() } else { Label("Add version", systemImage: "plus") }
                    }
                    .disabled(saving || rootId == 0 || profileId == 0)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.panel)
        .task { await load() }
        .onChange(of: tier) { seed() }
    }

    private func load() async {
        guard let client = model.client else { return }
        async let r = try? client.rootFolders()
        async let p = try? client.qualityProfiles()
        async let d = try? client.addDefaults()
        roots = await r ?? []
        profiles = await p ?? []
        defaults = await d ?? []
        seed()
    }

    /// `resolveTier`: the Add-defaults slot for (kind, tier), else the
    /// path / name heuristics (`edition-defaults.ts`).
    private func seed() {
        let slot = defaults.first(where: { $0.profileKind == resolvedKind && $0.tier == tier })
        let wants4k = tier == .uhd
        func is4k(_ s: String) -> Bool { s.range(of: "4k|2160|uhd", options: [.regularExpression, .caseInsensitive]) != nil }
        func kindMatch(_ path: String) -> Bool {
            path.range(of: item.kind == .series ? "tv|anime|series|show" : "movie|film", options: [.regularExpression, .caseInsensitive]) != nil
        }
        let root = roots.first(where: { kindMatch($0.path) && is4k($0.path) == wants4k })
            ?? roots.first(where: { kindMatch($0.path) }) ?? roots.first(where: { is4k($0.path) == wants4k }) ?? roots.first
        let profileIs4k: (QualityProfile) -> Bool = { $0.name.range(of: "4k|2160|uhd|ultra", options: [.regularExpression, .caseInsensitive]) != nil }
        let profile = (resolvedKind == "anime" ? profiles.first(where: { $0.mediaKind == "anime" && profileIs4k($0) == wants4k }) : nil)
            ?? profiles.first(where: { profileIs4k($0) == wants4k }) ?? profiles.first
        rootId = slot?.rootFolderId ?? root?.id ?? 0
        profileId = slot?.qualityProfileId ?? profile?.id ?? 0
    }

    private func submit() async {
        guard let client = model.client else { return }
        saving = true
        defer { saving = false }
        do {
            try await client.activityAddEdition(itemId: item.id, EditionAddRequest(tier: tier, rootFolderId: rootId, qualityProfileId: profileId,
                                                                           monitored: monitored, searchNow: searchNow))
            onAdded()
        } catch let e as APIError {
            self.error = e.serverDetail ?? (e.status == 409 ? "That edition already exists on this title." : "Couldn't add the edition. Try again.")
        } catch {
            self.error = "Couldn't add the edition. Try again."
        }
    }
}
