import SwiftUI
import FusionhaKit

/// One file, opened from the Files view or a card's ⓘ: v1's file detail
/// (`MIDetailPane`: the decision, Import as, Name vs file, the file), so
/// every per-file tool (assign, re-match, Import as, the item match, copy
/// path) stays one tap away. Its actions act at once, as in v1; the file
/// then leaves this page's choices.
struct V2MIFilePage: View {
    let rowId: Int
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        if let row = session.rows.first(where: { $0.rowId == rowId }) {
            ScrollView {
                MIDetailPane(row: row)
                    .background { ModuleSurface(radius: 18) }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
            .v2MIFooter()
        } else {
            ContentUnavailableView("This file is gone", systemImage: "doc",
                                   description: Text("It was imported or re-matched; it is in its new group."))
        }
    }
}
