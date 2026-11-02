import SwiftUI
import FusionhaKit

/// One version's live download, observed on its own: a card's version chips
/// read only their versions' slots, so a queue poll that moves one download
/// re-renders that one card.
@MainActor
@Observable
final class QueueSlot {
    fileprivate(set) var progress: QueueProgress?
}

/// Per-version views of `AppModel.queue` (as `SetupSlots` is for setups).
/// Every Library card's chips used to read the whole queue, so each 2s poll
/// while anything downloaded re-rendered every card in the grid.
@MainActor
final class QueueSlots {
    private var slots: [Int: QueueSlot] = [:]
    private var byEdition: [Int: QueueProgress] = [:]

    /// The slot for `editionId` (created on first use; never observed itself).
    func slot(for editionId: Int) -> QueueSlot {
        if let slot = slots[editionId] { return slot }
        let slot = QueueSlot()
        slot.progress = byEdition[editionId]
        slots[editionId] = slot
        return slot
    }

    /// A new queue: only the slots whose progress changed are touched. The
    /// first download per version wins, as the chips' old `queue.first` did.
    func update(_ queue: [QueueItem]) {
        var next: [Int: QueueProgress] = [:]
        for item in queue where next[item.editionId] == nil {
            next[item.editionId] = QueueProgress(item)
        }
        guard next != byEdition else { return }
        byEdition = next
        for (id, slot) in slots {
            let progress = next[id]
            if slot.progress != progress { slot.progress = progress }
        }
    }
}

extension View {
    /// Runs `action` with the queue whenever a poll changes it (and first with
    /// `initial`). The queue is read in a modifier of its own, so the view
    /// this is attached to doesn't re-render on every 2s poll (the shell and
    /// a title page on the open Duo's right page did).
    func onQueueChange(_ model: AppModel, initial: Bool = false, _ action: @escaping ([QueueItem]) -> Void) -> some View {
        modifier(QueueChange(model: model, initial: initial, action: action))
    }
}

private struct QueueChange: ViewModifier {
    let model: AppModel
    let initial: Bool
    let action: ([QueueItem]) -> Void

    func body(content: Content) -> some View {
        content.onChange(of: model.queue, initial: initial) { action(model.queue) }
    }
}
