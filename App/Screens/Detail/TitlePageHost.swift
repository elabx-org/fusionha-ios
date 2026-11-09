import SwiftUI
import FusionhaKit

extension EnvironmentValues {
    /// A replacement for the open title's page, in the sheet and the shell's
    /// column alike. v1 never sets it, so a title shows `ItemDetailView`; v2
    /// (`V2RootView`) passes its own title page here.
    @Entry var titlePage: TitlePageOverride?
}

/// The page a product shows for an open title, and how the shell lays it
/// out beside the list.
struct TitlePageOverride {
    /// The page for the title's store; the closure closes the column (nil
    /// in a sheet, which dismisses itself).
    let make: @MainActor (DetailStore, (() -> Void)?) -> AnyView
    /// The list's share of the flat open Duo while a title is open beside
    /// it (one seamless display, no fold gutter); nil keeps the shell's split.
    var flatOpenListShare: Double?
    /// A handle on that seamless split's seam (v2's `V2SplitHandle`); nil
    /// keeps the open Duo's leading-edge swipe (`DuoPageEdge`).
    var seamHandle: (@MainActor (DuoSeamContext) -> AnyView)?
    /// The open title's ground for the shell behind that seamless split
    /// (v2's `V2TitleShellGround`), so the system column and the display's
    /// foot are in the title's colours from its first frame; nil keeps the
    /// shell's plain ground.
    var shellGround: (@MainActor (Int) -> AnyView)?
    /// The pages pushed over the title (v2's seasons and episodes), kept
    /// per window so the sheet and the column show the same stack across a
    /// fold (`TitleStack`); the host passes itself so only the host on
    /// screen writes. nil keeps each host's own stack.
    var stackPath: (@MainActor (_ itemId: Int, _ host: DetailHost) -> Binding<NavigationPath>)?
    /// The strip drawn in the fold in book pose while a title is open beside
    /// the list (v2's `V2FoldSeam`); nil leaves the fold empty with a hairline.
    var foldSeam: (@MainActor (FoldSeamContext) -> AnyView)?
}

/// The open title's navigation stack, in the sheet and the column alike:
/// bound to the override's kept path when it has one, else its own.
struct TitleStack<Content: View>: View {
    @Environment(\.titlePage) private var override
    let itemId: Int
    let host: DetailHost
    @ViewBuilder var content: Content

    var body: some View {
        if let path = override?.stackPath?(itemId, host) {
            NavigationStack(path: path) { content }
        } else {
            NavigationStack { content }
        }
    }
}

/// Where the shell puts the open title: the override's page when one is
/// set, else v1's `ItemDetailView`.
struct TitlePageHost: View {
    @Environment(\.titlePage) private var override
    let store: DetailStore
    var onClose: (() -> Void)?

    var body: some View {
        if let override {
            override.make(store, onClose)
        } else {
            ItemDetailView(store: store, onClose: onClose)
        }
    }
}
