import SwiftUI
import FusionhaKit

extension View {
    /// One pick across the fold (`FoldPick`): open, the list's pick on its
    /// right page (`picked`); folded, the same item in the phone's sheet
    /// (`sheet`). When the layout changes the pick moves to the other one,
    /// so folding with a decision open shows it in its sheet, and unfolding
    /// with the sheet up puts it back on the right page.
    func foldPick<ID: Hashable, Item: Identifiable>(splits: Bool, picked: Binding<ID?>, sheet: Binding<Item?>,
                                                     id: @escaping (Item) -> ID,
                                                     item: @escaping (ID) -> Item?) -> some View {
        onChange(of: splits) { _, now in
            let next = FoldPick(picked: picked.wrappedValue, sheet: sheet.wrappedValue.map(id)).reconciled(splits: now)
            if picked.wrappedValue != next.picked { picked.wrappedValue = next.picked }
            if sheet.wrappedValue.map(id) != next.sheet { sheet.wrappedValue = next.sheet.flatMap(item) }
        }
    }
}
