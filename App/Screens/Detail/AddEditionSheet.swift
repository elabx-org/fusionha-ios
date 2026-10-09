import SwiftUI
import FusionhaKit

// MARK: - Add edition

struct AddEditionSheet: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let detail: ItemDetail
    let preset: AddEditionPreset

    private static let standard = "Standard"
    private static let custom = "__custom__"

    @State private var tier: QualityTier = .hd
    @State private var editionChoice = AddEditionSheet.standard
    @State private var customEdition = ""
    @State private var presets: [String] = []
    @State private var rootFolderId: Int?
    @State private var folderName = ""
    @State private var profileId: Int?
    @State private var monitor = "all"
    @State private var minimumAvailability = "released"
    @State private var monitored = true
    @State private var searchNow = true
    @State private var defaults: [AddDefaultSlot] = []
    @State private var busy = false
    @State private var error: String?
    @State private var checking = false
    @State private var fourK: FourKCheck?
    @State private var seeded = false

    private var isSeries: Bool { detail.isSeries }
    private var profiles: [QualityProfile] { DetailVocab.profiles(store.profiles, for: detail) }

    private var effectiveEdition: String? {
        if editionChoice == Self.custom {
            let v = customEdition.trimmingCharacters(in: .whitespaces)
            return v.isEmpty ? nil : v
        }
        return editionChoice == Self.standard ? nil : editionChoice
    }

    private var canSubmit: Bool {
        rootFolderId != nil && profileId != nil && !busy
            && !(editionChoice == Self.custom && effectiveEdition == nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tier", selection: $tier) {
                        ForEach(QualityTier.ordered, id: \.self) { Text($0.chipLabel).tag($0) }
                    }
                    Picker("Edition", selection: $editionChoice) {
                        ForEach([Self.standard] + presets, id: \.self) { Text($0).tag($0) }
                        Text("Custom…").tag(Self.custom)
                    }
                    if editionChoice == Self.custom {
                        LabeledContent("Custom edition name") {
                            TextField(isSeries ? "e.g. Remastered" : "e.g. Final Cut", text: $customEdition)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                } header: {
                    Text("\(detail.title) · a new tier + edition copy, tracked independently")
                        .textCase(nil)
                }

                if tier == .uhd {
                    fourKPanel
                }

                Section {
                    Picker("Root folder", selection: $rootFolderId) {
                        if rootFolderId == nil { Text("—").tag(Int?.none) }
                        ForEach(store.roots) { Text($0.path).tag(Int?.some($0.id)) }
                    }
                    LabeledContent("Folder name") {
                        TextField(defaultFolder, text: $folderName)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 14, design: .monospaced))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Text(previewPath)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.mut)
                    Picker("Quality profile", selection: $profileId) {
                        if profileId == nil { Text("—").tag(Int?.none) }
                        ForEach(profiles) { Text($0.name).tag(Int?.some($0.id)) }
                    }
                    if isSeries {
                        Picker("Monitor level", selection: $monitor) {
                            ForEach(DetailVocab.monitorOptions, id: \.value) { Text($0.label).tag($0.value) }
                        }
                    } else {
                        Picker("Minimum availability", selection: $minimumAvailability) {
                            ForEach(DetailVocab.minimumAvailability, id: \.value) { Text($0.label).tag($0.value) }
                        }
                    }
                    Toggle(isOn: $monitored) {
                        DialogFieldLabel(title: "Monitored", subtitle: "Track this version and grab it independently")
                    }
                    .tint(Theme.indigo)
                    .accessibilityLabel("Monitor version")
                    Toggle(isOn: $searchNow) {
                        DialogFieldLabel(title: "Search for releases now", subtitle: "Kick off a search as soon as the version is added")
                    }
                    .tint(Theme.indigo)
                }

                if let error {
                    Section {
                        Text(error).foregroundStyle(Theme.danger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Add a version")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if busy { ProgressView() } else { Label("Add version", systemImage: "plus") }
                    }
                    .disabled(!canSubmit)
                }
            }
            .onChange(of: tier) { _, next in
                reseed(next)
                fourK = nil
            }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.bg)
        .task { await seed() }
    }

    private var fourKPanel: some View {
        Section {
            if let fourK {
                let found = fourK.foundUhd == true
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fourK.message ?? (found ? "4K releases are available." : "No 4K releases found yet."))
                            .foregroundStyle(Theme.txt)
                        if let best = fourK.bestReleaseName {
                            Text(best).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.mut)
                        }
                    }
                } icon: {
                    Image(systemName: found ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .foregroundStyle(found ? Theme.done : Theme.miss)
                }
                .transition(.opacity)
            }
            Button {
                Task { await runFourKCheck() }
            } label: {
                HStack {
                    Label("Check indexers for 4K", systemImage: "magnifyingglass")
                    Spacer()
                    if checking { ProgressView() }
                }
            }
            .disabled(checking)
        } header: {
            Text("4K availability")
        } footer: {
            Text(isSeries
                 ? "A quick look at whether 4K releases of this show exist before you add the version."
                 : "A quick look at whether 4K releases of this movie exist before you add the version.")
        }
    }

    private var defaultFolder: String {
        detail.year.map { "\(detail.title) (\(String($0)))" } ?? detail.title
    }

    private var previewPath: String {
        let root = store.roots.first { $0.id == rootFolderId }?.path ?? "—"
        let folder = folderName.trimmingCharacters(in: .whitespaces)
        return root + "/" + (folder.isEmpty ? defaultFolder : folder)
    }

    private func reseed(_ next: QualityTier) {
        let slot = defaults.first { $0.profileKind == DetailVocab.profileKind(detail) && $0.tier == next }
        rootFolderId = slot?.rootFolderId ?? DetailVocab.defaultRoot(next, detail: detail, roots: store.roots)
        profileId = slot?.qualityProfileId ?? DetailVocab.defaultProfile(next, profiles: profiles)
    }

    private func seed() async {
        guard !seeded else { return }
        seeded = true
        minimumAvailability = store.settings?.defaultMovieMinimumAvailability ?? "released"
        let start = preset.tier ?? (detail.editions.contains { $0.tier == .uhd } ? .hd : .uhd)
        tier = start
        if let client = store.client {
            async let d = try? client.addDefaults()
            async let e = try? client.editionDefinitions()
            let (slots, definitions) = await (d, e)
            defaults = slots ?? []
            presets = (definitions ?? []).filter { $0.enabled != false }.map(\.name)
        }
        if let version = preset.version, !version.isEmpty {
            if presets.contains(version) { editionChoice = version } else {
                editionChoice = Self.custom
                customEdition = version
            }
        }
        reseed(start)
    }

    private func runFourKCheck() async {
        guard let client = store.client else { return }
        checking = true
        defer { checking = false }
        do {
            let result = try await client.checkFourK(itemId: detail.id)
            withAnimation(DetailMotion.quick) { fourK = result }
        } catch {
            store.show("Couldn't check for 4K releases", variant: .error)
        }
    }

    private func submit() async {
        guard let client = store.client, let rootFolderId, let profileId else { return }
        busy = true
        self.error = nil
        defer { busy = false }
        let folder = folderName.trimmingCharacters(in: .whitespaces)
        let body = EditionAdd(
            tier: tier, movieEdition: effectiveEdition, rootFolderId: rootFolderId, qualityProfileId: profileId,
            monitored: monitored, folderName: folder.isEmpty ? nil : folder,
            monitor: isSeries ? monitor : nil, minimumAvailability: isSeries ? nil : minimumAvailability,
            searchNow: searchNow)
        do {
            try await client.addEdition(itemId: detail.id, body)
            await store.reload()
            dismiss()
        } catch APIError.http(let status, _) where status == 409 {
            self.error = "That version (tier + edition) already exists on this title."
        } catch {
            self.error = "Could not add the version. Please try again."
        }
    }
}
