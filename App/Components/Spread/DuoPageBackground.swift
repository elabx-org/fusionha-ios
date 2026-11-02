import SwiftUI

// A sheet's own opaque `presentationBackground` sits deeper in the tree than
// the Duo page cover's `.clear`, so it wins: the whole cover window filled
// with the sheet's colour and the cover's dim drew over that, leaving a solid
// near-black page beside the sheet instead of the dimmed screen behind it.
//
// Sheets that can open on a Duo page set their background through
// `sheetBackground(_:)`, which steps aside on a page. The page itself keeps
// its solid fill (`DuoPageCover` draws `Theme.panel` behind it).

extension EnvironmentValues {
    /// True inside a Duo page cover (`duoPageSheet` on the open Duo).
    /// `sheetEscapeRoot()` clears it again for a plain sheet opened from a page.
    @Entry var onDuoPage = false
}

extension View {
    /// `presentationBackground(style)`, except on a Duo page, where the
    /// cover's clear background must show the dimmed window around the page.
    func sheetBackground<S: ShapeStyle>(_ style: S) -> some View {
        modifier(SheetBackground(style: style))
    }
}

private struct SheetBackground<S: ShapeStyle>: ViewModifier {
    @Environment(\.onDuoPage) private var onDuoPage
    let style: S

    func body(content: Content) -> some View {
        if onDuoPage {
            content
        } else {
            content.presentationBackground(style)
        }
    }
}
