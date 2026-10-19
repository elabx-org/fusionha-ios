import SwiftUI
import FusionhaKit

/// What Manage files opens on: the page's scope, or one version or season.
struct ManageFilesTarget: Identifiable {
    var versionIds: Set<Int>?
    var season: Int?
    var id: String { "\(versionIds?.sorted() ?? [])|\(season ?? -1)" }
}

/// Manage files / Manage episodes (web `ManageExistingFilesDialog`): the
/// title's registered files in the page's scope, each editable, replaceable,
/// movable and deletable, with a bulk bar for a selection; plus the
/// Import loose files tab.
struct ManageFilesSheet: View {
    @State private var model: ManageFilesModel
    @Environment(AppModel.self) private var app
    @Environment(DetailStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0
    @State private var selecting = false
    @State private var editing: ManageFilesEditTarget?
    @State private var confirm: ManageFilesConfirm?

    init(detail: ItemDetail, target: ManageFilesTarget) {
        _model = State(initialValue: ManageFilesModel(detail: detail, scopeVersionIds: target.versionIds, season: target.season))
    }

    var body: some View {
        NavigationStack {
            Group {
                if tab == 0 { filesList } else { ManageLooseFilesView(detail: model.detail) }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Picker("Show", selection: $tab) {
                    Text("Files").tag(0)
                    Text("Import loose files").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { if tab == 0 { bulkBar } }
            .navigationTitle(model.isSeries ? "Manage episodes" : "Manage files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .sheet(item: $editing) { t in ManageFileEditSheet(model: model, targets: t.items) }
            .confirmationDialog(confirm?.title(model) ?? "", isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }),
                                titleVisibility: .visible, presenting: confirm) { c in
                confirmButtons(c)
            } message: { c in
                if let m = c.message { Text(m) }
            }
        }
        .task {
            model.client = app.client
            await model.load()
        }
        .onDisappear { if model.changed { Task { await store.reload() } } }
        .retainsDraft("manage.model", $model)
        .retainsDraft("manage.tab", $tab)
        .retainsDraft("manage.selecting", $selecting)
    }

    // MARK: List

    @ViewBuilder private var filesList: some View {
        List {
            if let note = model.note {
                Label(note.text, systemImage: note.failed ? "exclamationmark.circle" : "checkmark.circle")
                    .font(.footnote)
                    .foregroundStyle(note.failed ? Theme.danger : Theme.done)
            }
            if !model.loaded {
                ProgressView().frame(maxWidth: .infinity)
            } else if model.loadFailed && model.items.isEmpty {
                Text("Couldn’t load this title’s files. Try Re-scan.").foregroundStyle(Theme.mut)
            } else if model.items.isEmpty {
                Text("No files under this title in this scope.").foregroundStyle(Theme.mut)
            } else {
                Section {
                    ForEach(model.items) { item in row(item) }
                } header: {
                    Text(model.subtitle).textCase(nil)
                } footer: {
                    Text("Replace deletes the file and searches for a new copy. An unmonitored file is only cleaned up.")
                }
            }
        }
        .refreshable { await model.load() }
    }

    private func row(_ item: ManagedFileItem) -> some View {
        Button {
            if selecting { model.toggle(item.id) } else { editing = ManageFilesEditTarget(items: [item]) }
        } label: {
            ManageFileRowView(item: item, selecting: selecting, selected: model.selected.contains(item.id))
        }
        .buttonStyle(.plain)
        .contextMenu { rowMenu(item) }
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive) { confirm = .delete([item]) }
        }
        .swipeActions(edge: .leading) {
            if item.monitored {
                Button(item.unreadable ? "Replace anyway" : "Replace", systemImage: "arrow.triangle.2.circlepath") { confirm = .replace([item]) }
                    .tint(Theme.i1)
            } else {
                Button("Clean up", systemImage: "link") { confirm = .cleanup([item]) }.tint(Theme.miss)
            }
        }
    }

    @ViewBuilder private func rowMenu(_ item: ManagedFileItem) -> some View {
        Button("Edit", systemImage: "pencil") { editing = ManageFilesEditTarget(items: [item]) }
        if item.monitored {
            Button(item.unreadable ? "Replace anyway" : "Replace", systemImage: "arrow.triangle.2.circlepath") { confirm = .replace([item]) }
        } else {
            Button("Clean up dead link", systemImage: "link") { confirm = .cleanup([item]) }
        }
        if model.canMove {
            Menu("Move to version", systemImage: "arrow.right.doc.on.clipboard") {
                ForEach(model.detail.editions.filter { $0.id != item.row.versionId }) { v in
                    Button(model.versionName(v) + (v.movieFile == nil ? "" : " · has a file")) { Task { await model.move(item, to: v) } }
                }
            }
        }
        Button("Delete", systemImage: "trash", role: .destructive) { confirm = .delete([item]) }
    }

    // MARK: Bars

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                Task { await model.rescan() }
            } label: {
                if model.rescanning { ProgressView() } else { Label("Re-scan", systemImage: "arrow.clockwise") }
            }
            .disabled(model.rescanning || tab != 0)
            Button(selecting ? "Cancel" : "Select") {
                selecting.toggle()
                if !selecting { model.selected = [] }
            }
            .disabled(tab != 0 || model.items.isEmpty)
        }
    }

    @ViewBuilder private var bulkBar: some View {
        if let n = model.deleting {
            HStack(spacing: 10) {
                ProgressView()
                Text("Deleting \(n) files…").font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .glassEffect(.regular, in: .capsule)
            .padding(.bottom, 8)
        } else if selecting {
            let picked = model.selectedItems
            GlassEffectContainer {
                HStack(spacing: 8) {
                    Button(model.allSelected ? "None" : "All") { model.toggleAll() }
                        .buttonStyle(.glass)
                    Button("Set…", systemImage: "pencil") { editing = ManageFilesEditTarget(items: picked) }
                        .buttonStyle(.glass).disabled(picked.isEmpty)
                    Spacer(minLength: 0)
                    Button("Replace", systemImage: "arrow.triangle.2.circlepath") { confirm = .replace(picked) }
                        .labelStyle(.iconOnly).buttonStyle(.glass).disabled(picked.isEmpty)
                    Button("Clean up", systemImage: "link") { confirm = .cleanup(picked) }
                        .labelStyle(.iconOnly).buttonStyle(.glass).disabled(picked.isEmpty)
                    Button("Delete", systemImage: "trash", role: .destructive) { confirm = .delete(picked) }
                        .labelStyle(.iconOnly).buttonStyle(.glass).tint(Theme.danger).disabled(picked.isEmpty)
                }
            }
            .disabled(model.busy)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .overlay(alignment: .top) {
                Text("\(picked.count) selected").font(.caption.weight(.semibold)).foregroundStyle(Theme.mut).offset(y: -18)
            }
        }
    }

    // MARK: ManageFilesConfirm

    @ViewBuilder private func confirmButtons(_ c: ManageFilesConfirm) -> some View {
        switch c {
        case .delete(let items):
            if items.count == 1 {
                Button("Delete file", role: .destructive) { Task { await model.delete(items) } }
                Button("Delete and blocklist release", role: .destructive) { Task { await model.delete(items, blocklist: true) } }
            } else {
                Button("Delete \(items.count) files", role: .destructive) { Task { await model.delete(items) } }
            }
        case .replace(let items):
            Button(items.count == 1 && items[0].unreadable ? "Replace anyway" : "Replace", role: .destructive) { Task { await model.replace(items) } }
        case .cleanup(let items):
            Button("Clean up", role: .destructive) { Task { await model.cleanup(items) } }
        }
        Button("Cancel", role: .cancel) {}
    }
}

struct ManageFilesEditTarget: Identifiable {
    let items: [ManagedFileItem]
    var id: [Int] { items.map(\.id) }
}

enum ManageFilesConfirm {
    case delete([ManagedFileItem]), replace([ManagedFileItem]), cleanup([ManagedFileItem])

    @MainActor func title(_ model: ManageFilesModel) -> String {
        switch self {
        case .delete(let items): return items.count == 1 ? "Delete \(items[0].name)?" : "Delete \(items.count) files?"
        case .replace(let items):
            let on = items.filter(\.monitored).count, off = items.count - on
            if items.count == 1 { return items[0].unreadable ? "Replace this unreadable file anyway?" : "Replace \(items[0].name)?" }
            return off > 0 ? "Replace \(on) · clean up \(off) unmonitored?" : "Replace \(on) files?"
        case .cleanup(let items): return items.count == 1 ? "Clean up this dead link?" : "Clean up \(items.count) dead links?"
        }
    }

    var message: String? {
        switch self {
        case .delete(let items):
            return items.count == 1 ? "The file is removed from disk and fusionha searches for a new copy. Blocklisting stops the same release coming back."
                : "The files are removed from disk. Monitored slots go back to Wanted."
        case .replace(let items):
            return items.count == 1 && items[0].unreadable ? "The file is present but fusionha couldn’t read it. Replacing deletes it and searches for a new copy."
                : "Each file is deleted and a new copy is searched for. fusionha stands down, deleting nothing, if the mount isn’t ready."
        case .cleanup: return "Removes the record of a file that’s gone. Nothing is searched for."
        }
    }
}
