import SwiftUI
import FusionhaKit

/// Add (a pasted address, previewed live) or Edit (the address is read-only)
/// an import list (web `ImportListForm`). Cancel and Save sit in the toolbar.
struct ImportListFormSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let store: ImportListsStore
    @State private var form: ImportListFormModel

    init(store: ImportListsStore, list: ImportList?) {
        self.store = store
        _form = State(initialValue: ImportListFormModel(list: list))
    }

    var body: some View {
        NavigationStack {
            Form {
                ImportListAddressSection(form: form) {
                    dismiss()
                    model.openSettings(panel: "indexers")
                }
                if let preview = form.preview, !form.draft.editing {
                    ImportListPreviewSection(preview: preview)
                }
                details
                ImportListVersionsSection(store: store, draft: $form.draft)
                schedule
                if let error = form.saveError {
                    Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(Theme.danger) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle(form.draft.editing ? ImportListCopy.edit : ImportListCopy.add)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(form.saving ? "Saving…" : "Save") {
                        Task { if await form.save(store, model) { dismiss() } }
                    }
                    .disabled(!form.canSave)
                }
            }
            .task { await store.loadChoices(model.client) }
            .task(id: form.previewKey) { await form.runPreview(model.client) }
        }
        .presentationDragIndicator(.visible)
    }

    private var details: some View {
        Section {
            TextField("Name", text: Binding(get: { form.draft.name }, set: { form.nameEdited($0) }))
            Picker("Media kind", selection: $form.draft.mediaKind) {
                ForEach(ImportListMediaKind.allCases, id: \.self) {
                    Text(ImportListCopy.kindWord($0.rawValue)).tag($0)
                }
            }
            .pickerStyle(.segmented)
            .disabled(form.draft.editing)
        } footer: {
            Text(ImportListCopy.kindHint(form.draft.mediaKind))
        }
    }

    private var schedule: some View {
        Section {
            switchRow(ImportListCopy.monitored, ImportListCopy.monitoredDesc, $form.draft.monitored)
            switchRow(ImportListCopy.searchOnAdd, ImportListCopy.searchOnAddDesc, $form.draft.searchOnAdd)
            Picker(selection: Binding(get: { form.draft.effectiveInterval }, set: { form.draft.intervalHours = $0 })) {
                ForEach(intervals, id: \.self) {
                    Text(ImportListCopy.every($0)).tag($0)
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ImportListCopy.checkEvery)
                    if form.draft.isLetterboxd {
                        Text(ImportListCopy.letterboxdEvery).font(.caption).foregroundStyle(Theme.mut)
                    }
                }
            }
            .pickerStyle(.menu)
            Toggle("Enabled", isOn: $form.draft.enabled)
        } footer: {
            Text(ImportListCopy.neverDeletes)
        }
    }

    /// The presets this list may use, plus its saved value when it is none of them.
    private var intervals: [Int] {
        let draft = form.draft
        let allowed = ImportListCopy.intervalPresets.filter { draft.intervalAllowed($0) }
        return allowed.contains(draft.effectiveInterval) ? allowed : (allowed + [draft.effectiveInterval]).sorted()
    }

    private func switchRow(_ title: String, _ desc: String, _ value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(desc).font(.caption).foregroundStyle(Theme.mut)
            }
        }
    }
}

/// "List address": the field (read-only when editing), the preview's problem
/// (Trakt's points at Settings › Indexers), and the Recognised line.
struct ImportListAddressSection: View {
    @Bindable var form: ImportListFormModel
    let openIndexers: () -> Void

    var body: some View {
        Section {
            TextField(ImportListCopy.addressPlaceholder, text: $form.draft.url)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .disabled(form.draft.editing)
                .foregroundStyle(form.draft.editing ? Theme.mut : Theme.txt)
                .accessibilityLabel("List address")
            if form.previewing {
                HStack(spacing: 6) { ProgressView().controlSize(.small); Text(FeedCopy.reading).foregroundStyle(Theme.mut) }
            }
            if let problem = form.problem {
                VStack(alignment: .leading, spacing: 4) {
                    Label(problem.text, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(problem.fatal ? Theme.danger : Theme.missText)
                    if problem.traktLink {
                        Button("Settings › Indexers", action: openIndexers).font(.footnote.weight(.semibold))
                    }
                }
                .font(.footnote)
            }
            if let provider = form.draft.provider {
                recognised(SourceProvider(feed: provider))
            }
        } header: {
            Text("List address")
        } footer: {
            if !form.draft.editing { Text(ImportListCopy.formDesc) }
        }
    }

    private func recognised(_ site: SourceProvider) -> some View {
        HStack(spacing: 10) {
            ProviderChip(provider: site, text: "\(site.word) · public list")
            if !form.draft.editing {
                Label(FeedCopy.recognised, systemImage: "checkmark")
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.text(.done))
            }
            if let owner = form.preview?.owner ?? form.listOwner {
                Text(FeedCopy.by(owner)).font(.caption).foregroundStyle(Theme.mut)
            }
        }
    }
}
