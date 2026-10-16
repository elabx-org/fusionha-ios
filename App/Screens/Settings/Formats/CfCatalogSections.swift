import SwiftUI
import FusionhaKit

/// The TRaSH custom-format catalog (web `CfCatalogPanel`): browse the guide by
/// media and category with counts, search by name (debounced off the server's
/// cached bundle), filter All / Not added, import one format or Select →
/// Import selected. Used inside TRaSH Guides and pushed from Custom Formats.
struct CfCatalogSections: View {
    @Binding var category: TrashCategory
    var mediaCounts: [TrashCategory: Int] = [:]
    var onImported: () async -> Void = {}
    @Environment(AppModel.self) private var model
    @State private var catalog: TrashCatalog?
    @State private var group: String?
    @State private var search = ""
    @State private var notAddedOnly = false
    @State private var selecting = false
    @State private var selected: Set<String> = []
    @State private var busy = false
    @State private var error: String?

    private var formats: [TrashCatalogEntry] {
        (catalog?.formats ?? []).filter { notAddedOnly ? !$0.isAdded : true }
    }

    private var loadKey: String { "\(category.rawValue)|\(search)|\(group ?? "")" }

    var body: some View {
        Section {
            TrashMediaPicker(category: $category, counts: mediaCounts)
        }
        .onChange(of: category) { group = nil; selected = [] }
        Section {
            TextField("Search by name…", text: $search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("Search custom formats")
            Picker("Category", selection: $group) {
                Text("All formats").tag(String?.none)
                ForEach(catalog?.groups ?? [], id: \.name) { g in
                    Text("\(g.name) (\(g.count ?? 0))").tag(Optional(g.name))
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.mut)
            Picker("Show", selection: $notAddedOnly) {
                Text("All").tag(false)
                Text("Not added").tag(true)
            }
            .pickerStyle(.segmented)
        }
        .listRowBackground(Theme.card)
        .task(id: loadKey) { await load(debounce: !search.isEmpty) }
        if selecting { bulkSection }
        Section {
            if catalog == nil && error == nil {
                SettingsLoadingRow()
            } else if formats.isEmpty {
                Text(search.isEmpty ? "No custom formats match." : "No formats match “\(search)”.")
                    .font(.system(size: 13)).foregroundStyle(Theme.mut)
            } else {
                ForEach(formats) { entry in row(entry) }
            }
            if let error { FormatsErrorRow(message: error) }
        } header: {
            HStack {
                Text("Custom formats").textCase(nil)
                Spacer()
                Button(selecting ? "Done" : "Select") { selecting.toggle(); selected = [] }
                    .font(.system(size: 13, weight: .semibold)).textCase(nil)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.mut)
        }
        .listRowBackground(Theme.card)
    }

    private var bulkSection: some View {
        Section {
            HStack {
                Text("**\(selected.count)** selected").foregroundStyle(Theme.txt)
                Spacer()
                Button("All") { selectAllVisible() }
                    .buttonStyle(.web(.ghost))
                    .accessibilityLabel("Select all visible")
                Button("Import selected", systemImage: "plus") { Task { await importIds(Array(selected), exit: true) } }
                    .buttonStyle(.web(.primary))
                    .disabled(busy || selected.isEmpty)
            }
        }
        .listRowBackground(Theme.card)
    }

    private func row(_ entry: TrashCatalogEntry) -> some View {
        HStack(spacing: 10) {
            if selecting {
                Button { toggle(entry.trashId) } label: {
                    Image(systemName: selected.contains(entry.trashId) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected.contains(entry.trashId) ? Theme.i1 : Theme.dim)
                }
                .buttonStyle(.plain)
                .disabled(entry.isAdded)
                .accessibilityLabel("Select \(entry.name)")
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
                if let summary = entry.specSummary, !summary.isEmpty { MonoText(summary, color: Theme.dim).lineLimit(2) }
                if let cat = entry.categories?.first { Text(cat).font(.caption2).foregroundStyle(Theme.mut) }
            }
            Spacer(minLength: 0)
            CfSignedScore(score: entry.score ?? 0)
            if entry.isAdded {
                Label("Added", systemImage: "checkmark").font(.caption.weight(.semibold)).foregroundStyle(Theme.done)
            } else if !selecting {
                Button("Import") { Task { await importIds([entry.trashId], exit: false) } }
                    .buttonStyle(.web(.primary))
                    .disabled(busy)
                    .accessibilityLabel("Import \(entry.name)")
            }
        }
    }

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    /// The bulk bar's "All": toggles every visible not-yet-added row.
    private func selectAllVisible() {
        let visible = formats.filter { !$0.isAdded }.map(\.trashId)
        let every = !visible.isEmpty && visible.allSatisfy { selected.contains($0) }
        selected = every ? [] : Set(visible)
    }

    private func load(debounce: Bool) async {
        guard let client = model.client else { return }
        if debounce {
            try? await Task.sleep(for: .milliseconds(250))
            if Task.isCancelled { return }
        }
        do {
            catalog = try await client.trashCatalog(category, search: search.trimmingCharacters(in: .whitespaces), group: group)
            error = nil
        } catch {
            if !Task.isCancelled { self.error = ErrorCopy.message(for: error, fallback: "Couldn’t load the catalog.") }
        }
    }

    private func importIds(_ ids: [String], exit: Bool) async {
        guard let client = model.client, !ids.isEmpty else { return }
        busy = true
        defer { busy = false }
        do {
            _ = try await client.trashImportFormats(category, trashIds: ids)
            if exit { selecting = false; selected = [] }
            await load(debounce: false)
            await onImported()
        } catch {
            self.error = error.settingsMessage
        }
    }
}

/// The catalog as a pushed page (Custom Formats › Browse TRaSH catalog).
struct CfCatalogScreen: View {
    var onImported: () async -> Void = {}
    @State private var category: TrashCategory = .movie

    var body: some View {
        FormatsSubpage(title: "TRaSH catalog") {
            CfCatalogSections(category: $category, onImported: onImported)
        }
    }
}
