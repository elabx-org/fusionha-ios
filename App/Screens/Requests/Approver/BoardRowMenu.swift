import SwiftUI
import FusionhaKit

/// Hold a Board row (joint ruling: the system context menu, not a custom
/// long-press sheet): Approve and Decline on Pending rows, then Open thread
/// and Open title.
struct BoardRowMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(DiscoverStore.self) private var store
    let request: MediaRequest
    let onApprove: (() -> Void)?
    let onDecline: (() -> Void)?
    let onThread: () -> Void

    var body: some View {
        if let onApprove { Button("Approve", systemImage: "checkmark", action: onApprove) }
        if let onDecline { Button("Decline…", systemImage: "xmark", role: .destructive, action: onDecline) }
        Button("Open thread", systemImage: "text.bubble", action: onThread)
        Button("Open title", systemImage: "arrow.up.right") {
            if let id = request.mediaItemId {
                model.open(id)
            } else {
                store.preview = PreviewRoute(kind: request.previewKind, tmdbId: request.tmdbId)
            }
        }
    }
}
