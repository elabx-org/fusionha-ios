import SwiftUI
import FusionhaKit

/// One title's running setup, observed on its own: a poster reads only its
/// slot, so a setup poll that changes one title re-renders that one poster.
@MainActor
@Observable
final class SetupSlot {
    fileprivate(set) var setup: TitleSetup?
}

/// Per-title views of `SetupProgress.list`. Every poster used to read the
/// whole list, so each poll that changed any setup (every 2s while one runs)
/// re-rendered every poster in the Library grid.
@MainActor
final class SetupSlots {
    private var slots: [Int: SetupSlot] = [:]
    private var list = TitleSetupList()

    /// The slot for `itemId` (created on first use; never observed itself).
    func slot(for itemId: Int) -> SetupSlot {
        if let slot = slots[itemId] { return slot }
        let slot = SetupSlot()
        slot.setup = active(itemId)
        slots[itemId] = slot
        return slot
    }

    /// A new list: only the slots whose setup changed are touched.
    func update(_ next: TitleSetupList) {
        list = next
        for (id, slot) in slots {
            let setup = active(id)
            if slot.setup != setup { slot.setup = setup }
        }
    }

    private func active(_ itemId: Int) -> TitleSetup? {
        list.setups.first { $0.itemId == itemId && $0.isActive }
    }
}
