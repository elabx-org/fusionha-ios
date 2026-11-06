import SwiftUI
import FusionhaKit

/// Which held download a decision is open for.
struct V2HeldRef: Identifiable, Hashable {
    let id: Int
}

/// The phone's (and folded Duo's) decision: a sheet over the queue, on the
/// held title's art ground, with Close and Open in Manual Import in its bar.
/// It follows the live queue row and closes itself once the download left.
struct HeldDecisionSheet: View {
    let ref: V2HeldRef
    let store: QueueStore
    let canDecide: Bool
    /// The queue's kept choice and scroll (fold continuity).
    var draft: HeldDecisionDraft?
    let review: (QueueItem) -> Void
    let perform: (HeldChoice, QueueItem) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            Group {
                if let item = store.items.first(where: { $0.id == ref.id }) {
                    HeldDecisionPage(item: item, siblings: V2QueueSiblings.of(item, in: store.items),
                                     canDecide: canDecide, draft: draft,
                                     review: { dismiss(); review(item) },
                                     perform: { await perform($0, item) },
                                     done: { dismiss() })
                        .v2PageGround(art: V2QueueGround.art(for: item, library: model.library))
                } else {
                    ContentUnavailableView("This download left the queue", systemImage: "checkmark.circle",
                                           description: Text("It was imported, removed or decided elsewhere."))
                }
            }
            .navigationTitle("Needs you")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

/// A held download's other versions in the queue (same title and episode).
enum V2QueueSiblings {
    static func of(_ item: QueueItem, in items: [QueueItem]) -> [QueueItem] {
        let key = QueueLogic.pairKey(item)
        return items.filter { $0.id != item.id && QueueLogic.pairKey($0) == key && $0.editionId != item.editionId }
    }
}

/// Which art a queue page sits on (mock cards-w.js `GROUND.queue`): the
/// held item's while a decision is open, else the first download's; its
/// library backdrop when the title is loaded, else its poster.
enum V2QueueGround {
    static func art(for item: QueueItem?, library: [MediaItem]) -> URL? {
        guard let item else { return nil }
        let backdrop = library.first { $0.id == item.mediaItemId }?.backdropUrl
        return PageArtSource.url(backdrop: backdrop, poster: item.posterUrl)
    }
}
