import SwiftUI
import FusionhaKit

// MARK: - Modals on the open iPhone Duo (S3)
//
// With the Duo open the window is regular width, so a `.sheet` is a form
// sheet centred in the window: on the Duo, centred on the fold. While a
// top-to-bottom fold runs through the window (flat or Book, in a Spread and
// in the Web layout alike) these present full screen over a dimmed window
// instead and place their content on a page (`DiscoverFold.modalTrack`):
//
// - `.rightPage`: the Spread's right page (the Add sheet, a preview, a
//   trailer, a collection), as a title opens there;
// - `.twoPages`: the whole window, for content that splits itself at the fold
//   (the request modal: the title on the left page, the options on the right).
//
// Folded, in portrait, on an iPad or a phone they are the usual sheets. The
// same item drives both, so folding or unfolding with one open keeps it open.

extension View {
    /// `.sheet(item:)`, or a page of the open Duo (`placement`). `onPages`
    /// overrides the environment's `duoOpen` (the shell's own sheets sit
    /// outside the environment it sets).
    func duoPageSheet<Item: Identifiable, Sheet: View>(item: Binding<Item?>,
                                                       placement: DiscoverFold.ModalPlacement = .rightPage,
                                                       onPages: Bool? = nil,
                                                       @ViewBuilder content: @escaping (Item) -> Sheet) -> some View {
        modifier(DuoPageSheet(item: item, placement: placement, onPages: onPages, sheet: content))
    }

    /// `.sheet(isPresented:)`, or a page of the open Duo.
    func duoPageSheet<Sheet: View>(isPresented: Binding<Bool>,
                                   placement: DiscoverFold.ModalPlacement = .rightPage,
                                   onPages: Bool? = nil,
                                   @ViewBuilder content: @escaping () -> Sheet) -> some View {
        let item = Binding<DuoPageFlag?>(
            get: { isPresented.wrappedValue ? DuoPageFlag() : nil },
            set: { isPresented.wrappedValue = $0 != nil }
        )
        return modifier(DuoPageSheet(item: item, placement: placement, onPages: onPages, sheet: { _ in content() }))
    }
}

/// `isPresented` as an item.
private struct DuoPageFlag: Identifiable {
    var id: Int { 0 }
}

private struct DuoPageSheet<Item: Identifiable, Sheet: View>: ViewModifier {
    @Environment(\.duoOpen) private var duoOpen
    @Binding var item: Item?
    let placement: DiscoverFold.ModalPlacement
    let onPages: Bool?
    let sheet: (Item) -> Sheet

    private var paged: Bool { onPages ?? duoOpen }

    func body(content: Content) -> some View {
        content
            .sheet(item: paged ? .constant(nil) : $item) { sheet($0) }
            .fullScreenCover(item: paged ? $item : .constant(nil)) { value in
                DuoPageCover(placement: placement) { sheet(value) }
            }
    }
}

/// The full-screen host: the window dimmed (tap to close) and the content on
/// its page, solid, with a hairline on the fold side like the title column.
private struct DuoPageCover<Content: View>: View {
    let placement: DiscoverFold.ModalPlacement
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss
    /// The cover's safe-area frame (the shell's) and the fold through it.
    @State private var measured = GridFold()

    private var track: FoldColumns.Track? {
        DiscoverFold.modalTrack(placement, width: Double(measured.width), fold: measured.foldRange)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.scrim.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }
                .accessibilityLabel("Close")
                .accessibilityAddTraits(.isButton)
            page
        }
        .onGeometryChange(for: GridFold.self) { GridFold($0) } action: { measured = $0 }
        .presentationBackground(.clear)
        // Sheets this one opens stay on the pages too.
        .environment(\.duoOpen, true)
        .duoHarness(backdrop: false)
    }

    private var page: some View {
        content
            .frame(width: track.map { CGFloat($0.width) } ?? measured.width)
            .frame(maxHeight: .infinity)
            .background(Theme.panel.ignoresSafeArea(edges: .vertical))
            .overlay(alignment: .leading) {
                if placement == .rightPage {
                    Rectangle().fill(Theme.line).frame(width: 1).ignoresSafeArea(edges: .vertical)
                }
            }
            .offset(x: track.map { CGFloat($0.x) } ?? 0)
    }
}
