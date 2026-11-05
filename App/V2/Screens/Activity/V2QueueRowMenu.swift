import SwiftUI
import FusionhaKit

/// What a queue row can do besides its tap (v1's card ⋯ and icon slots:
/// Re-grab, Remove, Interactive search, Blocklist, Copy release name).
struct V2QueueRowActions {
    var openTitle: (QueueItem) -> Void
    var remove: (QueueItem) -> Void
    var regrab: (QueueItem) -> Void
    var interactive: (QueueItem) -> Void
    var blocklist: (QueueItem) -> Void
    var copy: (QueueItem) -> Void
    var manualImport: (QueueItem) -> Void
}

/// The row's press-and-hold menu.
struct V2QueueRowMenu: View {
    let item: QueueItem
    let actions: V2QueueRowActions

    var body: some View {
        Button("Open title", systemImage: "film") { actions.openTitle(item) }
        if item.cockpitState == .held {
            Button("Review in Manual Import", systemImage: "square.and.arrow.down") { actions.manualImport(item) }
        }
        if item.grabHistoryId != nil {
            Button("Re-grab this release", systemImage: "arrow.uturn.down") { actions.regrab(item) }
        }
        Button("Interactive search", systemImage: "person") { actions.interactive(item) }
        Button("Blocklist without removing", systemImage: "nosign") { actions.blocklist(item) }
        Button("Copy release name", systemImage: "doc.on.doc") { actions.copy(item) }
        Divider()
        Button("Remove…", systemImage: "trash", role: .destructive) { actions.remove(item) }
    }
}
