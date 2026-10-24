import SwiftUI
import FusionhaKit

extension View {
    /// Caps a block of reading text at `ReadableWidth.max` (about 680 pt),
    /// leading-aligned, while its container keeps the full width. For
    /// overviews, taglines and section text; never for art, heroes, bars or
    /// grids.
    func readableWidth() -> some View {
        frame(maxWidth: CGFloat(ReadableWidth.max), alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
