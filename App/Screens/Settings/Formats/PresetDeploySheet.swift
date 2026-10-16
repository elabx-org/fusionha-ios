import SwiftUI
import FusionhaKit

/// Review & deploy (web `PresetDeployDialog`): nothing is created until
/// confirm. The profile name is editable; the ladder and Upgrade Until are
/// shown; every manifest format is tagged new / exists / unresolved under a
/// global conflict policy (Overwrite / Skip / Decide each). View opens it
/// read-only, and "Deploy…" switches it to the editable mode.
struct PresetDeploySheet: View {
    let preset: PresetInfo
    let sourceName: String?
    let onDeployed: (PresetDeployResult) -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var readOnly: Bool
    @State private var name: String
    @State private var mode: PresetConflictMode = .overwrite
    @State private var decisions: [String: String] = [:]
    @State private var replaceChoice = true
    @State private var allowUnresolved = false
    @State private var rows: [PresetFormatRow] = []
    @State private var profiles: [ProfileScoringSummary] = []
    @State private var working = false
    @State private var refusal: String?
    @State private var result: PresetDeployResult?

    init(preset: PresetInfo, viewOnly: Bool, sourceName: String?, onDeployed: @escaping (PresetDeployResult) -> Void) {
        self.preset = preset
        self.sourceName = sourceName
        self.onDeployed = onDeployed
        _readOnly = State(initialValue: viewOnly)
        _name = State(initialValue: preset.deployName)
    }

    /// The profile this deploy lands on, matched by name case-insensitively.
    private var target: ProfileScoringSummary? {
        let wanted = name.trimmingCharacters(in: .whitespaces).lowercased()
        return wanted.isEmpty ? nil : profiles.first(where: { $0.name.lowercased() == wanted })
    }
    private var ownedByThis: Bool { target?.deployedFromPresetId == preset.id }
    private var willReplace: Bool { ownedByThis && replaceChoice }
    private var counts: PresetDeployCounts { PresetDeployPlan.counts(rows, mode: mode, perRow: decisions) }

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                PresetLadderSection(ladder: PresetLadder.preview(preset.manifest))
                if !readOnly, let target { PresetTargetSection(target: target, owned: ownedByThis, presetId: preset.id,
                                                               replaceChoice: $replaceChoice, allowUnresolved: $allowUnresolved,
                                                               refusal: $refusal) { await loadProfiles() } }
                formatsSection
                if let result { PresetUnresolvedSection(result: result) }
                if let refusal { Section { FormatsErrorRow(message: refusal) } }
                Section { Text(summary).font(.system(size: 12.5)).foregroundStyle(Theme.mut) }
                    .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle(readOnly ? "Preset details" : "Review & deploy preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .task { await load() }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            SheetCancelButton(title: result != nil ? "Done" : (readOnly ? "Close" : "Cancel")) { finish() }
        }
        if result == nil {
            ToolbarItem(placement: .confirmationAction) {
                if readOnly {
                    Button("Deploy…") { readOnly = false }
                } else {
                    Button(working ? (willReplace ? "Rebuilding…" : "Deploying…") : (willReplace ? "Rebuild in place" : "Deploy to fusionha")) {
                        Task { await deploy() }
                    }
                    .disabled(working)
                }
            }
        }
    }

    private var profileSection: some View {
        Section {
            if readOnly {
                LabeledContent("Profile name", value: name)
            } else {
                TextField("Profile name", text: $name).accessibilityLabel("Profile name")
            }
        } header: {
            Text(readOnly ? "Profile" : "Profile — edit anything before deploying").textCase(nil)
        } footer: {
            Text("from \(sourceName ?? preset.name) · \(preset.mediaKind)")
        }
        .listRowBackground(Theme.card)
    }

    private var formatsSection: some View {
        Section {
            if !readOnly {
                Picker("If a format already exists", selection: $mode) {
                    ForEach(PresetConflictMode.allCases, id: \.self) { m in Text(m.label).tag(m) }
                }
                .pickerStyle(.menu)
                .tint(Theme.mut)
                .accessibilityLabel("Conflict policy")
            }
            ForEach(rows) { row in formatRow(row) }
        } header: {
            Text("Custom Formats (\(rows.count) in this preset)").textCase(nil)
        }
        .listRowBackground(Theme.card)
    }

    private func formatRow(_ row: PresetFormatRow) -> some View {
        let skipped = row.exists && PresetDeployPlan.decision(row, mode: mode, perRow: decisions) == "skip"
        return HStack(spacing: 8) {
            Text(row.name).font(.system(size: 13)).foregroundStyle(skipped ? Theme.dim : Theme.txt).lineLimit(2)
            Spacer(minLength: 0)
            FetchPill(text: row.status, tone: row.unresolvable ? .err : (row.exists ? .warn : .ok))
            CfSignedScore(score: row.score)
            if !readOnly && row.exists && mode == .perRow {
                Picker("Conflict decision for \(row.name)", selection: decisionBinding(row.key)) {
                    Text("Overwrite").tag("overwrite")
                    Text("Skip").tag("skip")
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }
        }
    }

    private func decisionBinding(_ key: String) -> Binding<String> {
        Binding(get: { decisions[key] ?? "overwrite" }, set: { decisions[key] = $0 })
    }

    /// The live `N new · M overwrite · K skip` (read-only: what it would create).
    private var summary: String {
        let c = counts
        let unres = c.unresolved > 0 ? " · \(c.unresolved) unresolved" : ""
        if let result {
            return "\(result.replaced == true ? "Rebuilt" : "Created") \(result.name) · \(result.createdFormats) new · \(result.overwritten) overwrite · \(result.skipped) skip"
        }
        if readOnly {
            return "Would create \(preset.deployName) · \(c.new) new · \(rows.count - c.new - c.unresolved) existing\(unres)"
        }
        let shown = name.trimmingCharacters(in: .whitespaces).isEmpty ? preset.deployName : name.trimmingCharacters(in: .whitespaces)
        return "\(willReplace ? "Rebuilds" : "Creates") \(shown) · \(c.new) new · \(c.overwrite) overwrite · \(c.skip) skip\(unres)"
    }

    private func finish() {
        if let result { onDeployed(result) }
        dismiss()
    }

    private func load() async {
        guard let client = model.client else { return }
        let category = TrashCategory(rawValue: preset.mediaKind) ?? .movie
        let catalog = (try? await client.trashCatalog(category).formats) ?? []
        let formats = (try? await client.customFormats()) ?? []
        rows = PresetDeployPlan.rows(preset, catalog: catalog, formats: formats)
        await loadProfiles()
    }

    private func loadProfiles() async {
        guard let client = model.client else { return }
        profiles = (try? await client.profileScoringSummaries()) ?? profiles
    }

    private func deploy() async {
        guard let client = model.client else { return }
        refusal = nil
        working = true
        defer { working = false }
        let body = PresetDeployPlan.body(name: name, rows: rows, mode: mode, perRow: decisions,
                                         replace: willReplace, allowUnresolved: allowUnresolved)
        do {
            let res = try await client.deployPreset(id: preset.id, body: body)
            // Dropped scores deserve a look: hold the sheet on the result.
            if (res.unresolved ?? []).isEmpty {
                onDeployed(res)
                dismiss()
            } else {
                result = res
            }
        } catch {
            refusal = error.settingsMessage
        }
    }
}
