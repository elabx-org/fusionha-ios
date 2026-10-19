import SwiftUI
import FusionhaKit

/// Edit › Metadata source and Episode numbering (EditItemDialog.tsx #43/#53).
/// A series picks TMDB / TheTVDB / Hybrid; another pick opens the reviewed
/// switch, never a bare save. Episode numbering: the provider's own
/// (Automatic) or a TVmaze / TheTVDB pin; a pin opens the reviewed numbering
/// fix against that source, Automatic resets the pin at once. Movies read TMDB.
struct EditSourceSection: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    @State private var resetting = false

    private var canEdit: Bool { model.me?.can("edit") ?? true }
    private var current: String { MetadataSwitchLogic.current(detail.metadataProvider ?? detail.resolvedMetadataProvider) }
    private var numberingDefault: String { MetadataSwitchLogic.numberingDefault(detail.resolvedMetadataProvider) }
    private var numbering: String {
        MetadataSwitchLogic.numberingSource(pin: detail.episodeNumberingSource, resolvedProvider: detail.resolvedMetadataProvider)
    }

    var body: some View {
        if detail.isSeries {
            Section {
                Picker(selection: Binding(get: { current }, set: { pick($0) })) {
                    ForEach(MetadataSwitchLogic.providers, id: \.self) { Text(MetadataSwitchLogic.label($0)).tag($0) }
                } label: {
                    DialogFieldLabel(title: "Metadata source",
                                     subtitle: "Switching re-fetches & reconciles — reviewed, never silent. Hybrid blends the best of each source per field.")
                }
                .disabled(!canEdit)
                Picker(selection: Binding(get: { numbering }, set: { pin($0) })) {
                    ForEach(MetadataSwitchLogic.numberingOptions(detail.resolvedMetadataProvider), id: \.0) { Text($0.1).tag($0.0) }
                } label: {
                    DialogFieldLabel(title: "Episode numbering", subtitle: numberingNote)
                }
                .disabled(!canEdit || resetting)
                if numbering != numberingDefault || detail.numberingMismatch == true {
                    Button("Review numbering…", systemImage: "list.number") {
                        open(numbering != numberingDefault ? numbering
                             : (numberingDefault == "tvdb" ? "tvdb" : "tvmaze"))
                    }
                    .disabled(!canEdit)
                }
            } footer: {
                if detail.metadataProvider == nil {
                    Text("Inherited from the global default — switch to pin it to this series.")
                }
            }
        } else {
            Section {
                LabeledContent {
                    Text("TMDB").foregroundStyle(Theme.mut)
                } label: {
                    DialogFieldLabel(title: "Metadata source", subtitle: "Movies use TMDB — TheTVDB & Hybrid apply to series only.")
                }
            }
        }
    }

    private var numberingNote: String {
        if numbering != numberingDefault { return "Pinned to \(MetadataSwitchLogic.label(numbering))." }
        if detail.numberingMismatch == true {
            return "\(numberingDefault == "tvdb" ? "TheTVDB" : "TVmaze") numbering looks different."
        }
        return "\(MetadataSwitchLogic.label(numberingDefault)) (default)"
    }

    private func pick(_ provider: String) {
        guard provider != current else { return }
        handOff { store.switchTarget = MetadataSwitchTarget(provider: provider) }
    }

    private func pin(_ source: String) {
        guard source != numbering else { return }
        if source == numberingDefault {
            Task { await reset() }
        } else {
            open(source)
        }
    }

    private func open(_ source: String) {
        handOff {
            store.numberingSource = source
            store.showingNumbering = true
        }
    }

    /// The edit sheet closes first; the next sheet opens from the page.
    private func handOff(_ next: @escaping @MainActor () -> Void) {
        store.showingEdit = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            next()
        }
    }

    private func reset() async {
        guard let client = store.client else { return }
        resetting = true
        defer { resetting = false }
        do {
            try await client.resetNumbering(itemId: detail.id)
            store.show("Episode numbering reset to \(MetadataSwitchLogic.label(numberingDefault)).", variant: .success)
            await store.reload()
        } catch {
            store.show(ErrorCopy.message(for: error), title: "Couldn’t reset the numbering", variant: .error)
        }
    }
}
