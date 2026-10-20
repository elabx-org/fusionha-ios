import SwiftUI
import FusionhaKit

/// Settings › Quality › Custom Formats (web `CustomFormatsPanel`): the format
/// library with search, provenance and kind filters and Select → bulk delete;
/// tap a format to open the condition-block editor with its live tester. The
/// TRaSH catalog, the arr / preset import and the full tester are pushed pages.
struct CustomFormatsSettingsPanel: View {
    @Environment(AppModel.self) private var model
    @State private var formats: [CustomFormatInfo]?
    @State private var profiles: [ProfileScoringSummary] = []
    @State private var error: String?
    @State private var query = ""
    @State private var chip = "all"
    @State private var kind = "all"
    @State private var editing: CfEditTarget?
    @State private var selecting = false
    @State private var selected: Set<Int> = []
    @State private var confirmBulk = false
    @State private var pendingDelete: CustomFormatInfo?
    @State private var toaster = FetchToaster()

    private var all: [CustomFormatInfo] { formats ?? [] }
    private var filtered: [CustomFormatInfo] { CFLibrary.filter(all, query: query, chip: chip, kind: kind) }

    var body: some View {
        SettingsForm(slug: "formats") {
            actions
            if let error {
                SettingsLoadingRow(error: error)
            } else if formats == nil {
                SettingsLoadingRow()
            } else {
                filters
                library
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $editing) { target in
            CustomFormatEditorSheet(target: target, profiles: profiles) { await load() }
        }
        .safeAreaInset(edge: .bottom) {
            if selecting && !selected.isEmpty { bulkBar.publishesBottomBarTop("settings.formats.bulk") }
        }
        .confirmationDialog("Delete \(selected.count) custom format\(selected.count == 1 ? "" : "s")?",
                            isPresented: $confirmBulk, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await bulkDelete() } }
        }
        .confirmationDialog("Delete \(pendingDelete?.name ?? "this format")?",
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) { if let f = pendingDelete { Task { await delete(f) } } }
        } message: {
            Text("Profiles stop scoring this format.")
        }
        .fetchToasts(toaster)
    }

    private var actions: some View {
        Section {
            Button("New format", systemImage: "plus") { editing = .new }
            NavigationLink { CfCatalogScreen { await load() } } label: {
                Label("Browse TRaSH catalog", systemImage: "books.vertical")
            }
            NavigationLink { CustomFormatImportScreen { await load() } } label: {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            NavigationLink { CustomFormatTesterScreen() } label: {
                Label("Open full tester", systemImage: "testtube.2")
            }
        }
        .listRowBackground(Theme.card)
    }

    private var filters: some View {
        Section {
            TextField("Search \(all.count) formats…", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("Filter custom formats")
            let chips = CFLibrary.chips(all)
            if chips.count > 2 {
                Picker("Provenance", selection: $chip) {
                    ForEach(chips, id: \.self) { c in
                        Text(CFLibrary.chipLabels.first(where: { $0.0 == c })?.1 ?? c).tag(c)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.mut)
            }
            Picker("Kind", selection: $kind) {
                Text("All").tag("all")
                ForEach(CFLibrary.kinds.indices, id: \.self) { i in
                    Text(CFLibrary.kinds[i].1).tag(CFLibrary.kinds[i].0)
                }
            }
            .pickerStyle(.segmented)
        }
        .listRowBackground(Theme.card)
    }

    private var library: some View {
        Section {
            ForEach(filtered) { format in
                CfLibraryRow(format: format, selecting: selecting, checked: selected.contains(format.id)) {
                    if selecting { toggle(format.id) } else { editing = .edit(format) }
                }
                .swipeActions(edge: .trailing) {
                    if !selecting {
                        Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = format }
                    }
                }
            }
            if filtered.isEmpty {
                Text(all.isEmpty ? "No custom formats yet." : "No custom formats match your filter.")
                    .font(.system(size: 13)).foregroundStyle(Theme.mut)
            }
        } header: {
            HStack {
                Text("All Formats").textCase(nil)
                Text("\(all.count)").monospacedDigit().foregroundStyle(Theme.dim)
                Spacer()
                if !all.isEmpty {
                    Button(selecting ? "Done" : "Select") {
                        selecting.toggle()
                        selected = []
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .textCase(nil)
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.mut)
        }
        .listRowBackground(Theme.card)
    }

    private var bulkBar: some View {
        HStack(spacing: 10) {
            Text("\(selected.count) selected").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
            Spacer(minLength: 0)
            Button("Select all") { selected = Set(filtered.map(\.id)) }.buttonStyle(.web(.ghost))
            Button("Delete", systemImage: "trash") { confirmBulk = true }.buttonStyle(.web(.danger))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: Capsule())
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func toggle(_ id: Int) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            formats = try await client.customFormats()
            profiles = (try? await client.profileScoringSummaries()) ?? profiles
            error = nil
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t load the custom formats.")
        }
    }

    private func bulkDelete() async {
        guard let client = model.client else { return }
        do {
            let result = try await client.bulkDeleteCustomFormats(ids: Array(selected))
            toaster.show(result.message, tone: result.hadSkips ? .error : .success)
            selecting = false
            selected = []
            await load()
        } catch { toaster.error(error, title: "Couldn’t delete the custom formats") }
    }

    private func delete(_ format: CustomFormatInfo) async {
        guard let client = model.client else { return }
        do {
            try await client.deleteCustomFormat(id: format.id)
            await load()
        } catch { toaster.error(error, title: "Couldn’t delete \(format.name)") }
    }
}

enum CfEditTarget: Identifiable {
    case new
    case edit(CustomFormatInfo)

    var id: Int { if case .edit(let f) = self { return f.id }; return -1 }
    var format: CustomFormatInfo? { if case .edit(let f) = self { return f }; return nil }
}

/// One library row: name, then kind tag · provenance · N specs · ↻ rename.
private struct CfLibraryRow: View {
    let format: CustomFormatInfo
    let selecting: Bool
    let checked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if selecting {
                    Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(checked ? Theme.i1 : Theme.dim)
                        .font(.system(size: 18))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(format.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt).lineLimit(2)
                    HStack(spacing: 6) {
                        CfKindTag(kind: format.mediaKind)
                        CfSourceBadge(source: format.provenance)
                        Text(CFLibrary.specCount(format.specifications.count))
                        if format.includeWhenRenaming == true { Text("↻ rename").foregroundStyle(Theme.i2) }
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.mut)
                }
                Spacer(minLength: 0)
                if !selecting {
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.dim)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selecting ? "Select \(format.name)" : "Edit \(format.name)")
        .accessibilityAddTraits(checked ? .isSelected : [])
    }
}
