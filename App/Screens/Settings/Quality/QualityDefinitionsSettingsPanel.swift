import SwiftUI
import FusionhaKit

/// Settings › Quality › Quality Definitions (web `QualityDefinitionsPanel`):
/// every quality's size window in MB per runtime-minute, grouped by resolution
/// under collapsible headers. Drag the min · preferred · max handles or type
/// min / max; a runtime preview turns each window into GB per file. Edits save
/// per row (`PUT /api/v1/qualitydefinitions/{id}`), debounced.
struct QualityDefinitionsSettingsPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var defs: [QualityDefinitionRecord]?
    @State private var error: String?
    @State private var saveError: String?
    @State private var runtime = 45
    @State private var runtimeText = "45"
    @State private var collapsed: Set<String> = []
    @State private var pending: [Int: Task<Void, Never>] = [:]
    @State private var confirmReset = false

    var body: some View {
        SettingsForm(slug: "qualitydefinitions") {
            preview
            if let error {
                SettingsLoadingRow(error: error)
            } else if let defs {
                ForEach(QualitySizeLimits.grouped(defs), id: \.name) { group in
                    groupSection(group.name, group.rows)
                }
                footer(defs)
            } else {
                SettingsLoadingRow()
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .confirmationDialog("Reset every size limit to the arr / TRaSH defaults?", isPresented: $confirmReset,
                            titleVisibility: .visible) {
            Button("Reset to defaults", role: .destructive) { resetDefaults() }
        }
    }

    private var preview: some View {
        SettingsSection("Size limits", footer: "Drag the min · preferred · max handles") {
            LabeledContent {
                HStack(spacing: 8) {
                    Picker("Runtime preset", selection: Binding(get: { runtime }, set: { setRuntime($0) })) {
                        Text("Episode").tag(45)
                        Text("Movie").tag(120)
                        if runtime != 45 && runtime != 120 { Text("Custom").tag(runtime) }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                    TextField("Preview runtime in minutes", text: $runtimeText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.body.monospacedDigit())
                        .frame(width: 44)
                        .onChange(of: runtimeText) {
                            if let v = Int(runtimeText.trimmingCharacters(in: .whitespaces)), v > 0 { runtime = v }
                        }
                    Text("min").font(.caption).foregroundStyle(Theme.mut)
                }
            } label: {
                FieldLabel(label: "Preview for")
            }
            .settingsField("Preview for")
        }
    }

    private func groupSection(_ name: String, _ rows: [QualityDefinitionRecord]) -> some View {
        let open = !collapsed.contains(name)
        return Section {
            if open {
                ForEach(rows) { def in
                    QualityDefinitionRow(def: def, runtime: runtime) { range in persist(def, range) }
                }
            }
        } header: {
            Button {
                SettingsMotion.perform(motionOff) {
                    if open { collapsed.insert(name) } else { collapsed.remove(name) }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(open ? 90 : 0))
                    Text(name).font(.system(size: 15, weight: .semibold))
                    Text("\(rows.count)").font(.caption.monospacedDigit()).foregroundStyle(Theme.dim)
                }
                .foregroundStyle(Theme.mut)
                .textCase(nil)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityValue(open ? "Expanded" : "Collapsed")
        }
        .listRowBackground(Theme.card)
        .listRowSeparatorTint(Theme.line)
    }

    private func footer(_ defs: [QualityDefinitionRecord]) -> some View {
        let sorted = QualitySizeLimits.grouped(defs).flatMap(\.rows)
        let span = sorted.last.flatMap { worst in
            sorted.first.map { " · \(QualityLadder.label(worst.quality)) → \(QualityLadder.label($0.quality))" }
        } ?? ""
        return Section {
            HStack {
                Text("\(defs.count) qualities\(span)").font(.caption).foregroundStyle(Theme.mut)
                Spacer(minLength: 8)
                Button("Reset to defaults") { confirmReset = true }
                    .buttonStyle(.web(.ghost))
                    .settingsField("Reset to defaults")
            }
            if let saveError {
                Text(saveError).font(.footnote).foregroundStyle(Theme.danger)
            }
        } footer: {
            Text("Min / preferred / max are **MB per runtime-minute**. The decision engine rejects a release outside **[min, max]** and uses **preferred** to break ties. Dragging max to the end of the axis means **∞** — no upper bound.")
                .font(.system(size: 13)).foregroundStyle(Theme.dim)
        }
        .listRowBackground(Theme.card)
    }

    private func setRuntime(_ v: Int) {
        runtime = v
        runtimeText = String(v)
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            defs = try await client.qualityDefinitionRecords()
            error = nil
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t load the quality definitions.")
        }
    }

    /// Coalesce rapid edits into one PUT per definition (350 ms after the last).
    private func persist(_ def: QualityDefinitionRecord, _ range: QualitySizeRange) {
        pending[def.id]?.cancel()
        pending[def.id] = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, let client = model.client else { return }
            do {
                try await client.updateQualityDefinition(def, range)
                guard !Task.isCancelled else { return }
                saveError = nil
                pending[def.id] = nil
                if pending.isEmpty { await load() }
            } catch {
                guard !Task.isCancelled else { return }
                saveError = ErrorCopy.message(for: error, fallback: "Couldn’t save \(QualityLadder.label(def.quality)).")
            }
        }
    }

    private func resetDefaults() {
        for def in defs ?? [] {
            if let d = QualitySizeLimits.defaults[def.quality] { persist(def, d) }
        }
    }
}
