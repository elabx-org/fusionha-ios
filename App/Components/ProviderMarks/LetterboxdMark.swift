import SwiftUI

/// The Letterboxd mark (the web's `LbIcon` in `account/letterboxd/icons.tsx`):
/// three overlapping outlined dots on a 24×24 grid, stroked 1.8 in
/// `Theme.letterboxdMark`. Decorative unless `label` is passed.
struct LetterboxdMark: View {
    var size: CGFloat = 16
    var label: String?

    var body: some View {
        let color = Theme.letterboxdMark
        Canvas { context, canvasSize in
            context.scaleBy(x: canvasSize.width / 24, y: canvasSize.height / 24)
            for x in [6.5, 12, 17.5] as [CGFloat] {
                let dot = Path(ellipseIn: CGRect(x: x - 3.6, y: 12 - 3.6, width: 7.2, height: 7.2))
                context.stroke(dot, with: .color(color), lineWidth: 1.8)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(label == nil)
        .accessibilityLabel(label ?? "")
        .accessibilityAddTraits(label == nil ? [] : .isImage)
    }
}

/// The rail heading's mark in its 26pt tile (`.acc`: the mark's colour at 16%).
struct LetterboxdMarkTile: View {
    var body: some View {
        LetterboxdMark(size: 16)
            .frame(width: 26, height: 26)
            .background(Theme.letterboxdMark.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
