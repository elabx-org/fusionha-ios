import SwiftUI
import FusionhaKit

/// One row's decisions: accept, quality profile, monitoring, the cut, and
/// Override / Match. Reads the live row by key, so a poll or rescan shows
/// through, and every edit goes through the workspace's auto-save.
struct ImportRowEditorSheet: View {
    let model: ImportWorkspaceModel
    let itemId: String
    let onOverride: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var edition = ""
    @FocusState private var editionFocused: Bool

    private var item: LibraryImportItem? { model.item(itemId) }

    var body: some View {
        NavigationStack {
            Group {
                if let item {
                    form(item)
                } else {
                    ContentUnavailableView("This folder is gone", systemImage: "folder.badge.questionmark",
                                           description: Text("A rescan dropped or merged it."))
                }
            }
            .navigationTitle(item?.title ?? "Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    SheetDoneButton { commitEdition(); dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { edition = item.map { detectedEdition($0) } ?? "" }
    }

    private func form(_ item: LibraryImportItem) -> some View {
        let locked = !item.matched || !model.isDraft
        let selected = LibraryImportRules.resolvedProfile(item, in: model.profiles)
        let options = LibraryImportRules.profiles(model.profiles, for: item, keep: selected)
        return Form {
            Section {
                ForEach(item.versions ?? [], id: \.self) { v in
                    HStack(spacing: 8) {
                        TierPill(tier: v.tier)
                        MonoText(v.folder).lineLimit(2)
                    }
                }
                if item.matched {
                    LabeledContent("Match", value: "\(item.title) (\(item.year.map(String.init) ?? "—"))")
                    LabeledContent("Confidence", value: item.confidence)
                } else {
                    Text("No match found").foregroundStyle(Theme.miss)
                }
            }
            Section {
                Toggle("Accept", isOn: Binding(get: { item.accepted }, set: { model.setAccepted(item, $0) }))
                Picker("Quality profile", selection: Binding(
                    get: { selected },
                    set: { id in
                        if let id { model.queue(LibraryImportPatch(scanId: item.scanId, folderKey: item.folderKey, qualityProfileId: id)) }
                    })) {
                    if selected == nil { Text("Profile").tag(Int?.none) }
                    ForEach(options) { p in Text(p.name).tag(Int?.some(p.id)) }
                }
                Toggle(isOn: Binding(get: { item.monitored }, set: {
                    model.queue(LibraryImportPatch(scanId: item.scanId, folderKey: item.folderKey, monitored: $0))
                })) {
                    Label("Monitor", systemImage: item.monitored ? "bookmark.fill" : "bookmark")
                }
                LabeledContent("Edition") {
                    TextField("Standard", text: $edition)
                        .multilineTextAlignment(.trailing)
                        .focused($editionFocused)
                        .submitLabel(.done)
                        .onSubmit(commitEdition)
                        .accessibilityLabel("Edition for \(item.title)")
                }
            }
            .disabled(locked)
            .tint(Theme.i1)
            Section {
                Button(item.matched ? "Override match" : "Find match", systemImage: "arrow.triangle.swap") {
                    commitEdition()
                    onOverride()
                    dismiss()
                }
                .disabled(!model.isDraft)
            } footer: {
                if !model.isDraft { Text("This import is finished, so its rows are read-only.") }
            }
        }
        .onChange(of: editionFocused) { if !editionFocused { commitEdition() } }
    }

    private func detectedEdition(_ item: LibraryImportItem) -> String {
        item.variant ?? item.versions?.first?.edition ?? ""
    }

    /// Saves the cut once, when it changed.
    private func commitEdition() {
        guard let item, item.matched, model.isDraft, edition != detectedEdition(item) else { return }
        model.queue(LibraryImportPatch(scanId: item.scanId, folderKey: item.folderKey, variant: edition))
    }
}
