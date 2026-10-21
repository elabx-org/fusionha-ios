import SwiftUI
import FusionhaKit

// MARK: - iPhone Duo Spread (S1 infrastructure)
//
// Open with a top-to-bottom fold (inner landscape, flat or Book) and the
// "iPhone Duo, open" setting on Spread, the shell is two pages split at the
// fold's real x with the 40 pt gutter (`SpreadGeometry` in FusionhaKit): the
// tab on the left page, the picked item on the right (`SpreadRightPage`).
// The Web layout (the setting's other value) is the web-parity wide layout,
// untouched.
//
// Extension points for the per-screen batches (S2–S6):
// - `@Environment(\.spread)`: whether the screen is in a Spread, the pages in
//   the shell's coordinates, and whether its content spans both pages.
//   Screens switch to their Spread layouts on `spread.isActive`.
// - `.spreadSpansBothPages(tab)`: a browse screen asks for its content to
//   fill both pages while nothing is picked (the shell drops the right page;
//   the screen lays its content out in two fold-separated halves with
//   `FoldSpanRow` and `PosterTracks`). Picking a title moves it back to the
//   left page and opens the title on the right.
// - `SpreadRightPage`: the right page's default per tab when nothing is
//   picked ("never empty, the most useful real item").

/// The shell's Spread state, handed to every screen as `\.spread`.
struct SpreadContext: Equatable {
    var mode: SpreadGeometry.Mode = .off

    /// In a Spread (either mode): the screen should use its Spread layout.
    var isActive: Bool { mode != .off }
    /// The tab fills both pages (a browse screen with nothing picked).
    var spans: Bool { mode.spans }
    /// The pages, in the shell's coordinates.
    var pages: SpreadGeometry.Pages? { mode.pages }

    init() {}

    init(fold: FoldInfo, layout: DuoOpenLayout, spanRequested: Bool, hasItem: Bool) {
        let x = fold.vertical ?? fold.flatVertical
        mode = SpreadGeometry.mode(layout: layout, width: Double(fold.size.width),
                                   fold: x.map { Double($0.lowerBound)...Double($0.upperBound) },
                                   spanRequested: spanRequested, hasItem: hasItem)
    }
}

extension EnvironmentValues {
    /// The shell's Spread state (`SpreadContext`).
    @Entry var spread = SpreadContext()
    /// The iPhone Duo is open with a top-to-bottom fold (flat or Book), so the
    /// "iPhone Duo, open" choice applies and its toolbar switch shows.
    @Entry var duoOpen = false
}

extension FoldInfo {
    /// A top-to-bottom fold runs through the container, active or flat.
    var isDuoOpen: Bool { vertical != nil || flatVertical != nil }
}

/// The tabs that ask to span both pages while nothing is picked. Owned by the
/// shell; screens register through `.spreadSpansBothPages(_:)`.
@MainActor
@Observable
final class SpreadSpanRequests {
    private(set) var tabs: Set<AppTab> = []

    func set(_ tab: AppTab, spans: Bool) {
        if spans, !tabs.contains(tab) { tabs.insert(tab) }
        if !spans, tabs.contains(tab) { tabs.remove(tab) }
    }

    func spans(_ tab: AppTab) -> Bool { tabs.contains(tab) }
}

extension EnvironmentValues {
    @Entry var spreadSpanRequests: SpreadSpanRequests? = nil
}

private struct SpreadSpanRequest: ViewModifier {
    @Environment(\.spreadSpanRequests) private var requests
    let tab: AppTab
    let enabled: Bool

    func body(content: Content) -> some View {
        content.onChange(of: enabled, initial: true) { requests?.set(tab, spans: enabled) }
    }
}

extension View {
    /// A browse screen asks the Spread to give it both pages while nothing is
    /// picked (Library now; Discover and Search in S3).
    func spreadSpansBothPages(_ tab: AppTab, _ enabled: Bool = true) -> some View {
        modifier(SpreadSpanRequest(tab: tab, enabled: enabled))
    }
}
