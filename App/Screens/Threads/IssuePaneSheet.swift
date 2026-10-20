import SwiftUI
import FusionhaKit

/// A manager's issue thread as a sheet (the phone; a form sheet unfolded,
/// ruling R7): `IssuePaneView` under the title's name, with Done and Open in
/// library. Wide in Requests › Threads or Issues it is the split's pane.
struct IssuePaneSheet: View {
    let seed: MediaIssue
    let linkedRequestId: Int?
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            IssuePaneView(seed: seed, linkedRequestId: linkedRequestId)
                .navigationTitle(seed.mediaTitle ?? "Issue")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { SheetDoneButton { dismiss() } }
                    ToolbarItem(placement: .topBarLeading) {
                        Button { dismiss(); model.open(seed.mediaItemId) } label: { Image(systemName: "arrow.up.right.square") }
                            .accessibilityLabel("Open in library")
                    }
                }
        }
        .presentationDetents([.large])
        .formSheet() // R7: a form sheet when unfolded
    }
}
