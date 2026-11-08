import SwiftUI
import FusionhaKit

/// What Needs you's Review opens (`ManageFilesTarget.problems`): Fix mode,
/// and, from its "Show" line, the normal Manage episodes (a movie's Manage
/// files) with the problem files still ticked. Opened any other way, those
/// sheets show as before.
struct V2ReviewFilesSheet: View {
    let detail: ItemDetail
    let target: ManageFilesTarget
    @State private var showsAll = false

    var body: some View {
        Group {
            if showsAll {
                if detail.isSeries {
                    V2ManageEpisodesSheet(detail: detail, target: target)
                } else {
                    ManageFilesSheet(detail: detail, target: target)
                }
            } else {
                V2FixSheet(detail: detail, target: target, showAll: { showsAll = true })
            }
        }
        .retainsDraft("manage.fix.all", $showsAll)
    }
}
