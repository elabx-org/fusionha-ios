import SwiftUI
import FusionhaKit

extension AppModel {
    /// The release-group routes are `integrations.manage`-gated.
    var mayBlockGroups: Bool { me?.hasPermission("integrations.manage") == true }
}

/// Title › More › "Release groups" (the shared More menu, v2 only).
struct V2ReleaseGroupsMenuItem: View {
    @Environment(AppModel.self) private var model
    let store: DetailStore

    var body: some View {
        if model.mayBlockGroups {
            Button("Release groups", systemImage: "tag") { store.showingReleaseGroups = true }
        }
    }
}

/// "Block <GROUP>" in a row's menu, when the row names a group that is not
/// blocked here yet. It opens the block sheet over the title page, or
/// hands the group to `open` (a sheet that presents its own).
struct V2BlockGroupButton: View {
    @Environment(AppModel.self) private var model
    @Environment(DetailStore.self) private var store
    let group: String?
    var open: ((String) -> Void)?

    var body: some View {
        if model.mayBlockGroups, let name = TitleGroupBlocks.display(group), store.groupBlock(for: name) == nil {
            Button("Block \(name)", systemImage: "nosign") {
                if let open { open(name) } else { store.blockGroup = GroupBlockTarget(group: name) }
            }
        }
    }
}
