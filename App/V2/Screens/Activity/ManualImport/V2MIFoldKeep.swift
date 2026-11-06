import SwiftUI
import FusionhaKit

/// Manual Import across a fold (`docs/v2.md`, "Fold continuity"). Folding or
/// unfolding swaps its presentation (a sheet folded, both pages open), which
/// builds the view again; the scan, the choices and the pushed pages live
/// here (`FoldKeep`) until Activity closes it (`ActivityView`).
@MainActor
final class V2MIKept {
    let session: ManualImportSession
    let store = V2MIDraftStore()
    /// The phone's pushed pages, for the next host.
    var path: [V2MIRoute] = []

    init(downloadIds: [Int], client: APIClient?) {
        session = ManualImportSession(rescueIds: downloadIds, client: client)
    }

    static func key(_ downloadIds: [Int]) -> String {
        "mi-" + downloadIds.map(String.init).joined(separator: ",")
    }
}

/// Builds Manual Import on the window's kept models.
struct V2ManualImportHost: View {
    let downloadIds: [Int]
    let client: APIClient?
    let onOpenWeb: () -> Void
    @Environment(\.foldKeep) private var keep

    var body: some View {
        let kept = keep?.object(V2MIKept.key(downloadIds)) { V2MIKept(downloadIds: downloadIds, client: client) }
        V2ManualImportView(downloadIds: downloadIds, client: client, kept: kept, onOpenWeb: onOpenWeb)
    }
}

/// The open card on the split and the phone's pushed page are one
/// selection (`FoldRoute`): the split shows a group or a file, the phone
/// pushes it.
@MainActor
enum V2MIFoldRoute {
    static func reconcile(split: Bool, path: inout [V2MIRoute], store: V2MIDraftStore) {
        if split {
            let picked = FoldRoute.picked(from: path, current: current(store)) { _ in true }
            switch picked {
            case .group(let problem): store.segment = .groups; store.focus = problem
            case .file(let row): store.segment = .files; store.fileFocus = row
            case nil: break
            }
            path = []
        } else {
            path = FoldRoute.stack(picked: current(store), stack: path)
        }
    }

    /// The split's open card, by segment.
    private static func current(_ store: V2MIDraftStore) -> V2MIRoute? {
        switch store.segment {
        case .groups: store.focus.map(V2MIRoute.group)
        case .files: store.fileFocus.map(V2MIRoute.file)
        }
    }
}
