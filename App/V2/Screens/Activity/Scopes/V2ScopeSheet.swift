import SwiftUI
import FusionhaKit

/// The phone's version of a scope's right page: the same pane in a sheet,
/// on the item's ground, with Done in the bar and its own toaster so toasts
/// show over the sheet.
struct V2ScopeSheet<Content: View>: View {
    let title: String
    var art: String?
    @ViewBuilder var content: () -> Content
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var toaster = ActToaster()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) { content() }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
            .v2PageGround(art: PageArtSource.url(backdrop: nil, poster: art))
        }
        .overlay { ActToastOverlay(toaster: toaster) }
        .environment(toaster)
        .presentationDetents([.medium, .large])
        // Open title / Interactive search open the title over Activity:
        // this sheet steps aside first.
        .onChange(of: model.presentedItem) { _, item in
            if item != nil { dismiss() }
        }
    }
}
