import SwiftUI
import FusionhaKit

/// The Add / Edit import list form (web `use-import-list-form.ts`): the
/// draft, the live preview of a pasted address (debounced 400 ms; a 429
/// retries quietly after 5 s), and Save.
@MainActor
@Observable
final class ImportListFormModel {
    var draft: ImportListDraft
    var preview: ImportListPreview?
    var problem: ImportListCopy.Problem?
    var previewing = false
    var saving = false
    var saveError: String?
    /// The name was typed: a preview no longer fills it.
    private var nameTyped: Bool
    private let fallbackName: String
    /// The edited list's owner (its Recognised line).
    let listOwner: String?

    init(list: ImportList?) {
        draft = list.map(ImportListDraft.init(editing:)) ?? ImportListDraft()
        nameTyped = list != nil
        fallbackName = list?.name ?? ""
        listOwner = list?.owner
    }

    var canSave: Bool { !saving && draft.canSave(problemIsFatal: problem?.fatal == true) }
    var previewKey: String { "\(draft.trimmedURL)|\(draft.mediaKind.rawValue)" }

    func nameEdited(_ text: String) {
        nameTyped = true
        draft.name = text
    }

    /// Run by the sheet's `task(id: previewKey)`.
    func runPreview(_ client: APIClient?) async {
        guard !draft.editing, let client else { return }
        let url = draft.trimmedURL
        // A new address forgets the last preview's site and the name it filled.
        preview = nil
        problem = nil
        previewing = false
        draft.provider = nil
        if !nameTyped { draft.name = "" }
        guard !url.isEmpty else { return }
        try? await Task.sleep(for: .milliseconds(400))
        while !Task.isCancelled {
            previewing = true
            do {
                let read = try await client.previewImportList(url: url, mediaKind: draft.mediaKind)
                previewing = false
                guard !Task.isCancelled else { return }
                preview = read
                draft.provider = read.provider
                if !nameTyped { draft.name = read.title ?? "" }
                return
            } catch {
                previewing = false
                guard !Task.isCancelled else { return }
                problem = ImportListCopy.problem(error)
                // A rate-limited preview retries quietly.
                guard problem == nil else { return }
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func save(_ store: ImportListsStore, _ model: AppModel) async -> Bool {
        guard let client = model.client, canSave else { return false }
        saving = true
        saveError = nil
        defer { saving = false }
        do {
            if let id = draft.editingId {
                _ = try await client.updateImportList(id, draft.patchBody(fallbackName: fallbackName))
            } else {
                _ = try await client.createImportList(draft)
            }
            await store.load(client)
            return true
        } catch {
            saveError = ImportListCopy.serverMessage(error)
            return false
        }
    }
}
