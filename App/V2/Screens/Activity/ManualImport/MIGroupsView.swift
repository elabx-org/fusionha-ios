import SwiftUI
import FusionhaKit

/// The pack as cards, one per problem (mock `grp`), in display order. The
/// chips narrow it to cards with a file doing that. `lean` is the open
/// Duo's list: no sentence, and the open card ringed.
struct MIGroupsView: View {
    var lean = false
    let open: (MIProblem) -> Void
    @Environment(ManualImportSession.self) private var session
    @Environment(V2MIDraftStore.self) private var store

    var body: some View {
        let groups = store.groups(session).filter { g in g.rows.contains { store.shows($0, session) } }
        VStack(spacing: 10) {
            ForEach(groups) { g in
                MIGroupCard(group: g, lean: lean, selected: lean && store.focus == g.problem) { open(g.problem) }
            }
            if groups.isEmpty {
                Text("No files here.").font(.footnote).foregroundStyle(Theme.mut).padding(.top, 8)
            }
        }
    }
}
