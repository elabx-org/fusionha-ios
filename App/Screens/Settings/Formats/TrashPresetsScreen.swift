import SwiftUI
import FusionhaKit

/// TRaSH Guides › Presets (web `PresetsTab`): deploy a curated profile bundle —
/// the TRaSH custom formats with your own scoring, quality ladder and upgrade
/// rules — in one go. View / Deploy open the review sheet; Re-import shows the
/// arr connections a preset is captured from.
struct TrashPresetsScreen: View {
    @Environment(AppModel.self) private var model
    @State private var presets: [PresetInfo]?
    @State private var connections: [ArrConnection] = []
    @State private var profiles: [ProfileScoringSummary] = []
    @State private var names: [String: [String: String]] = [:]
    @State private var deployedIds: Set<Int> = []
    @State private var showCapture = false
    @State private var reviewing: PresetReview?
    @State private var renaming: PresetInfo?
    @State private var renameText = ""
    @State private var deployingAll = false
    @State private var error: String?
    @State private var toaster = FetchToaster()

    private var list: [PresetInfo] { presets ?? [] }
    private var deployedCount: Int { list.filter(isDeployed).count }

    var body: some View {
        FormatsSubpage(title: "Presets") {
            Section {
                Text("Deploy a **curated profile bundle** — the TRaSH custom formats with your own scoring, quality ladder, and upgrade rules — into fusionha in one click. Each is a portable **trash-id-keyed** manifest, so it survives guide updates and can be shared.")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                Toggle(isOn: $showCapture) {
                    FieldLabel(label: "Re-import", description: "Snapshotted from \(connections.count) connected arrs")
                }
                .tint(Theme.i1)
            }
            .listRowBackground(Theme.card)
            if showCapture || (presets != nil && list.isEmpty) {
                ArrConnectionsSections(connections: connections, toaster: toaster) { await load() }
            }
            if presets == nil {
                error.map { SettingsLoadingRow(error: $0) } ?? SettingsLoadingRow()
            } else if list.isEmpty {
                Section { Text("No presets yet — connect an arr above and capture a profile.").foregroundStyle(Theme.mut) }
                    .listRowBackground(Theme.card)
            } else {
                ForEach(list) { preset in
                    PresetCardSection(preset: preset, names: names[preset.mediaKind] ?? [:],
                                      from: connections.first(where: { $0.id == preset.sourceConnectionId })?.name,
                                      deployed: isDeployed(preset),
                                      onView: { reviewing = PresetReview(preset: preset, viewOnly: true) },
                                      onDeploy: { reviewing = PresetReview(preset: preset, viewOnly: false) },
                                      onRename: { renameText = preset.name; renaming = preset })
                }
                deployBar
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $reviewing) { review in
            PresetDeploySheet(preset: review.preset, viewOnly: review.viewOnly,
                              sourceName: connections.first(where: { $0.id == review.preset.sourceConnectionId })?.name) { result in
                markDeployed(review.preset, result)
                Task { await loadProfiles() }
            }
        }
        .alert("Rename preset", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Preset name", text: $renameText)
            Button("Save") { if let p = renaming { Task { await rename(p) } } }
            Button("Cancel", role: .cancel) {}
        }
        .fetchToasts(toaster)
    }

    private var deployBar: some View {
        Section {
            HStack {
                Text("**\(deployedCount)** of \(list.count) deployed").foregroundStyle(Theme.txt)
                Spacer()
                if deployedCount < list.count {
                    Button("Deploy all \(list.count - deployedCount) to fusionha", systemImage: "arrow.down.to.line") {
                        Task { await deployAll() }
                    }
                    .buttonStyle(.web(.primary))
                    .disabled(deployingAll)
                }
            }
        }
        .listRowBackground(Theme.card)
    }

    private func isDeployed(_ preset: PresetInfo) -> Bool {
        deployedIds.contains(preset.id) || profiles.contains { $0.name == preset.deployName }
    }

    private func markDeployed(_ preset: PresetInfo, _ result: PresetDeployResult) {
        deployedIds.insert(preset.id)
        toaster.show(result.toast)
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            presets = try await client.presets()
            error = nil
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t load the presets.")
        }
        connections = (try? await client.arrConnections()) ?? connections
        await loadProfiles()
        for c in TrashCategory.allCases where names[c.rawValue] == nil {
            if let catalog = try? await client.trashCatalog(c) {
                names[c.rawValue] = Dictionary(catalog.formats.map { ($0.trashId, $0.name) }, uniquingKeysWith: { a, _ in a })
            }
        }
    }

    private func loadProfiles() async {
        guard let client = model.client else { return }
        profiles = (try? await client.profileScoringSummaries()) ?? profiles
    }

    /// A taken name is refused (409) and reported; an unchanged one is a no-op.
    private func rename(_ preset: PresetInfo) async {
        let next = renameText.trimmingCharacters(in: .whitespaces)
        guard let client = model.client, !next.isEmpty, next != preset.name else { return }
        do {
            try await client.renamePreset(id: preset.id, name: next)
            await load()
        } catch { toaster.error(error) }
    }

    /// Deploys every un-deployed preset with its defaults; bulk never replaces.
    private func deployAll() async {
        guard let client = model.client else { return }
        deployingAll = true
        defer { deployingAll = false }
        let body: SettingsJSON = .object(["conflict": "skip", "replace": false, "allow_unresolved": false])
        for preset in list where !isDeployed(preset) {
            do {
                let result = try await client.deployPreset(id: preset.id, body: body)
                markDeployed(preset, result)
            } catch {
                toaster.show("Deploy \(preset.deployName) failed: \(error.settingsMessage)", tone: .error)
            }
        }
        await loadProfiles()
    }
}

struct PresetReview: Identifiable {
    let preset: PresetInfo
    let viewOnly: Bool
    var id: Int { preset.id }
}
