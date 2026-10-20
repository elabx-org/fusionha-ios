import SwiftUI
import FusionhaKit

/// One version's card in the Edit sheet: monitoring, storage, profile and the
/// remove button, editing the sheet's draft for that edition.
struct EditEditionSection: View {
    @Environment(DetailStore.self) private var store
    let detail: ItemDetail
    let edition: DetailEdition
    let draft: Binding<EditItemSheet.Draft>
    let original: EditItemSheet.Draft?
    @Binding var removing: DetailEdition?

    private var isSeries: Bool { detail.isSeries }

    var body: some View {
        Section {
            if isSeries {
                Picker("Monitor", selection: draft.monitor) {
                    ForEach(DetailVocab.monitorOptions, id: \.value) { Text($0.label).tag($0.value) }
                }
            } else {
                Toggle(isOn: draft.monitored) {
                    Label(draft.wrappedValue.monitored ? "Monitored" : "Unmonitored",
                          systemImage: draft.wrappedValue.monitored ? "bookmark.fill" : "bookmark")
                }
                .tint(Theme.indigo)
            }
            Picker("Root folder", selection: draft.rootFolderId) {
                if draft.wrappedValue.rootFolderId == nil { Text("—").tag(Int?.none) }
                ForEach(store.roots) { root in
                    Text(root.path).font(.system(.body, design: .monospaced)).tag(Int?.some(root.id))
                }
            }
            LabeledContent("Folder name") {
                TextField("Folder name", text: draft.folderName)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 14, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Picker("Quality profile", selection: draft.qualityProfileId) {
                if draft.wrappedValue.qualityProfileId == nil { Text("—").tag(Int?.none) }
                ForEach(DetailVocab.profiles(store.profiles, for: detail, keep: edition.qualityProfileId)) { profile in
                    Text(profile.name).tag(Int?.some(profile.id))
                }
            }
            if !isSeries {
                Picker("Minimum availability", selection: draft.minimumAvailability) {
                    ForEach(DetailVocab.minimumAvailability, id: \.value) { Text($0.label).tag($0.value) }
                }
            }
            if let original {
                let d = draft.wrappedValue
                let storageChanged = d.rootFolderId != original.rootFolderId
                    || d.folderName.trimmingCharacters(in: .whitespaces) != original.folderName
                let hasFiles = detail.fileCount(edition) > 0
                VStack(alignment: .leading, spacing: 4) {
                    Text(previewPath(d))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.mut)
                        .textSelection(.enabled)
                    if storageChanged && edition.movieEdition != nil && d.folderName != original.folderName {
                        Text("⚠ folder rename — your media server re-scans it as a new item; watch history resets")
                            .font(.system(size: 11.5)).foregroundStyle(Theme.miss)
                    } else if storageChanged {
                        Text("↪ move files on save").font(.system(size: 11.5)).foregroundStyle(Theme.edition)
                    }
                }
                if storageChanged && hasFiles {
                    Picker("Existing files", selection: draft.disposition) {
                        ForEach(DetailVocab.dispositions, id: \.value) { Text($0.label).tag($0.value) }
                    }
                    if d.disposition == "leave" {
                        Text("Files stay in the old folder and show as Missing until moved or re-imported.")
                            .font(.system(size: 11.5)).foregroundStyle(Theme.miss)
                    } else if d.disposition == "delete" {
                        Text("The existing files will be permanently deleted.")
                            .font(.system(size: 11.5)).foregroundStyle(Theme.danger)
                    }
                }
            }
            if detail.editions.count > 1 {
                Button(role: .destructive) { removing = edition } label: {
                    Label("Remove version", systemImage: "trash")
                }
            } else {
                Label("The last version can’t be removed — delete the title instead", systemImage: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.dim)
            }
        } header: {
            HStack(spacing: 8) {
                Text(edition.tier.chipLabel)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(DetailTokens.tier(edition.tier))
                if let version = edition.movieEdition, !version.isEmpty {
                    DetailVersionTag(text: version)
                }
            }
            .textCase(nil)
        }
    }

    private func previewPath(_ draft: EditItemSheet.Draft) -> String {
        let root = store.roots.first { $0.id == draft.rootFolderId }?.path ?? "—"
        let folder = draft.folderName.trimmingCharacters(in: .whitespaces)
        return root + "/" + (folder.isEmpty ? defaultFolder : folder)
    }

    private var defaultFolder: String {
        detail.year.map { "\(detail.title) (\(String($0)))" } ?? detail.title
    }
}
