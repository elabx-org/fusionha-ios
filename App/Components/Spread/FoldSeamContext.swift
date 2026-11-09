import SwiftUI

/// What the shell hands a product's strip at the fold in book pose (v2's
/// `V2FoldSeam`, `TitlePageOverride.foldSeam`): the display's size, the
/// fold's x-range in the shell's coordinates and the title open beside the
/// list. Only offered half open, with the fold top to bottom.
struct FoldSeamContext {
    let size: CGSize
    let gap: ClosedRange<CGFloat>
    let itemId: Int
}
