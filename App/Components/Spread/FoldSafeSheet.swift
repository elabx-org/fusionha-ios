import SwiftUI
import FusionhaKit

// MARK: - Sheets from a title on the right of the iPhone Duo's fold
//
// With the Duo open the window is regular width, so a `.sheet` becomes a form
// sheet centred in the window: on the Duo that is centred on the fold. While
// the title is the trailing column beside the fold (a Spread's right page, or
// the Web layout's title column; flat or Book), its sheets (interactive
// search, Edit, Add version, the item actions…) open as popovers hanging from
// the top of that column instead, sized to it, so they stay on the right page.
// Anywhere else (folded, portrait, an iPad, the phone) they are the usual
// sheets. The same presentation flag drives both, so nothing else changes.

/// The column a title's sheets present in: its frame in global coordinates
/// and the top safe area (`ItemDetailView` sets it while beside the fold).
struct FoldSafePage: Equatable {
    var frame: CGRect
    var topInset: CGFloat

    /// The popover's size: the column less a margin each side, most of its height.
    var size: CGSize {
        CGSize(width: max(frame.width - 24, 280), height: max(frame.height - topInset - 56, 320))
    }
}

extension EnvironmentValues {
    /// Set while the open title is a column beside the Duo's fold.
    @Entry var foldSafePage: FoldSafePage? = nil
}

/// The presenting view's global origin, kept out of SwiftUI's invalidation
/// (scrolling moves it every frame; it is only read when a sheet opens).
private final class OriginBox {
    var origin: CGPoint = .zero
}

private struct FoldSafeSheetModifier<Item: Identifiable, Sheet: View>: ViewModifier {
    @Environment(\.foldSafePage) private var page
    @Binding var item: Item?
    let sheet: (Item) -> Sheet
    @State private var box = OriginBox()

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGPoint.self) { $0.frame(in: .global).origin } action: { box.origin = $0 }
            .sheet(item: page == nil ? $item : .constant(nil)) { sheet($0) }
            .popover(item: page == nil ? .constant(nil) : $item, attachmentAnchor: anchor, arrowEdge: Optional(Edge.bottom)) { value in
                sheet(value)
                    .frame(idealWidth: page?.size.width, idealHeight: page?.size.height)
                    .presentationCompactAdaptation(.popover)
                    // A sheet opened from this one is a plain sheet over it.
                    .environment(\.foldSafePage, nil)
            }
    }

    /// The top centre of the column, in this view's coordinates.
    private var anchor: PopoverAttachmentAnchor {
        guard let page else { return .rect(.bounds) }
        let x = page.frame.midX - box.origin.x
        let y = page.frame.minY + page.topInset + 6 - box.origin.y
        return .rect(.rect(CGRect(x: x - 1, y: y, width: 2, height: 2)))
    }
}

/// `isPresented` as an item, for the flag-driven sheets.
private struct PresentedFlag: Identifiable {
    var id: Int { 0 }
}

extension View {
    /// `.sheet(item:)`, or a popover on the title's column beside the Duo's fold.
    func foldSafeSheet<Item: Identifiable, Sheet: View>(item: Binding<Item?>,
                                                        @ViewBuilder content: @escaping (Item) -> Sheet) -> some View {
        modifier(FoldSafeSheetModifier(item: item, sheet: content))
    }

    /// `.sheet(isPresented:)`, or a popover on the title's column beside the Duo's fold.
    func foldSafeSheet<Sheet: View>(isPresented: Binding<Bool>,
                                    @ViewBuilder content: @escaping () -> Sheet) -> some View {
        let item = Binding<PresentedFlag?>(
            get: { isPresented.wrappedValue ? PresentedFlag() : nil },
            set: { isPresented.wrappedValue = $0 != nil }
        )
        return modifier(FoldSafeSheetModifier(item: item, sheet: { _ in content() }))
    }
}

extension View {
    /// The title's column hands its frame to its sheets while it is beside
    /// the Duo's fold (`active`), so they open on it (`foldSafeSheet`).
    func foldSafePageHost(active: Bool) -> some View {
        modifier(FoldSafePageHost(active: active))
    }
}

private struct FoldSafePageHost: ViewModifier {
    let active: Bool
    @State private var page: FoldSafePage?

    func body(content: Content) -> some View {
        content
            .environment(\.foldSafePage, active ? page : nil)
            .onGeometryChange(for: FoldSafePage.self) { proxy in
                FoldSafePage(frame: proxy.frame(in: .global), topInset: proxy.safeAreaInsets.top)
            } action: { page = $0 }
    }
}
