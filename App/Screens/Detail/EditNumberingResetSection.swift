import SwiftUI
import FusionhaKit

/// Edit › Episode numbering (web `EditItemDialog`'s source picker, reset
/// half): a series pinned to TVmaze or TheTVDB numbering can go back to its
/// own provider's. Reversible, so there is no confirm; picking another source
/// stays the reviewed Fix episode numbering flow on the detail page.
struct EditNumberingResetSection: View {
    let itemId: Int
    let source: String
    let provider: String?
    @Environment(AppModel.self) private var model
    @Environment(DetailStore.self) private var store
    @State private var working = false

    private var owner: String {
        switch provider {
        case "tvdb": return "TheTVDB"
        case "hybrid": return "Hybrid"
        default: return "TMDB"
        }
    }

    private var pinned: String {
        switch source {
        case "tvmaze": return "TVmaze"
        case "tvdb": return "TheTVDB"
        default: return source.uppercased()
        }
    }

    var body: some View {
        Section {
            LabeledContent("Numbering", value: pinned)
            Button(working ? "Resetting…" : "Reset to \(owner) numbering", systemImage: "arrow.uturn.backward") {
                Task { await reset() }
            }
            .disabled(working)
        } header: {
            Text("Episode numbering")
        } footer: {
            Text("Episodes and their files are re-filed onto \(owner)’s numbering. You can pin another source again later.")
        }
    }

    private func reset() async {
        guard let client = model.client else { return }
        working = true
        defer { working = false }
        do {
            try await client.resetNumbering(itemId: itemId)
            model.toast("Episode numbering reset to \(owner).")
            await store.reload()
        } catch {
            model.toast(ErrorCopy.message(for: error), title: "Couldn’t reset the numbering", variant: .error)
        }
    }
}
