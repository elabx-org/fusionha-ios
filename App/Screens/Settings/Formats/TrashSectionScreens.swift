import SwiftUI
import FusionhaKit

/// TRaSH Guides › Custom Formats: the catalog over the shared Media choice.
struct TrashCatalogScreen: View {
    @Binding var category: TrashCategory
    let counts: [TrashCategory: Int]

    var body: some View {
        FormatsSubpage(title: "Custom Formats") {
            CfCatalogSections(category: $category, mediaCounts: counts)
        }
    }
}

/// TRaSH Guides › Overrides & Conflicts (web `ConflictsTab`): every local
/// override that diverges from the latest guide — auto-sync preserves these —
/// with the one resolution, Reset to guide.
struct TrashConflictsScreen: View {
    @Environment(AppModel.self) private var model
    @State private var conflicts: [TrashConflict]?
    @State private var resetting: Int?
    @State private var error: String?

    var body: some View {
        FormatsSubpage(title: "Overrides & Conflicts") {
            if let conflicts {
                if conflicts.isEmpty {
                    Section { Text("No overrides — your formats match the guide.").foregroundStyle(Theme.mut) }
                        .listRowBackground(Theme.card)
                }
                ForEach(conflicts) { c in conflictSection(c) }
                if let error { Section { FormatsErrorRow(message: error) } }
            } else if let error {
                SettingsLoadingRow(error: error)
            } else {
                Section { Text("Checking your overrides against the guide…").foregroundStyle(Theme.mut) }
                    .listRowBackground(Theme.card)
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func conflictSection(_ c: TrashConflict) -> some View {
        Section {
            HStack(spacing: 8) {
                FetchPill(text: "overridden", tone: .warn)
                Text(c.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
                FetchChip(text: c.mediaKind)
            }
            specLine("yours", TrashText.specs(c.localSpecs), color: Theme.miss)
            specLine("guide", TrashText.specs(c.guideSpecs), color: Theme.done)
            Button(resetting == c.cfId ? "Resetting…" : "Reset to guide", systemImage: "arrow.uturn.backward") {
                Task { await reset(c) }
            }
            .disabled(resetting != nil)
            .accessibilityLabel("Reset \(c.name) to guide")
        }
        .listRowBackground(Theme.card)
    }

    private func specLine(_ label: String, _ text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10.5, weight: .heavy)).foregroundStyle(Theme.dim)
            MonoText(text, color: color)
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            conflicts = try await client.trashConflicts().conflicts
            error = nil
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t check your overrides against the guide.")
        }
    }

    private func reset(_ c: TrashConflict) async {
        guard let client = model.client else { return }
        resetting = c.cfId
        defer { resetting = nil }
        do {
            try await client.resetCustomFormat(id: c.cfId)
            await load()
        } catch {
            self.error = error.settingsMessage
        }
    }
}
