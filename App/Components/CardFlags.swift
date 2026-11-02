import SwiftUI

/// One Library card's "picked" (the title open on a Spread's right page) and
/// "selected" (select mode) flags, observed on their own.
@MainActor
@Observable
final class CardFlag {
    fileprivate(set) var picked = false
    fileprivate(set) var selected = false
}

/// Per-title views of `AppModel.presentedItem` and `selection`. Every card
/// read both, so opening or swiping to another title on the open Duo, or
/// ticking one card in select mode, re-rendered every card the grid had
/// realized; now only the cards whose flag flips do.
@MainActor
final class CardFlags {
    private var slots: [Int: CardFlag] = [:]
    private var pickedId: Int?
    private var selection: Set<Int> = []

    /// The flags for `itemId` (created on first use; never observed itself).
    func slot(for itemId: Int) -> CardFlag {
        if let slot = slots[itemId] { return slot }
        let slot = CardFlag()
        slot.picked = itemId == pickedId
        slot.selected = selection.contains(itemId)
        slots[itemId] = slot
        return slot
    }

    func pick(_ itemId: Int?) {
        guard itemId != pickedId else { return }
        if let old = pickedId { slots[old]?.picked = false }
        pickedId = itemId
        if let itemId { slots[itemId]?.picked = true }
    }

    func select(_ next: Set<Int>) {
        guard next != selection else { return }
        let changed = selection.symmetricDifference(next)
        selection = next
        for id in changed { slots[id]?.selected = next.contains(id) }
    }
}
