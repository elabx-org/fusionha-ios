import SwiftUI
import FusionhaKit

// MARK: - Collapsed tabs (owner-approved 2026-11-10, v2, on trial)
//
// On the iPhone Duo the system keeps a column on the trailing edge for the
// clock, the page's buttons and the tabs. With this on, the tabs leave the
// column: one arrow button (the first item, so the system puts it in the
// first free spot under the clock) grows the bar into a pill of their icons
// (`ColumnPill`), with the page's own buttons and Account under them, so the column
// holds the arrow (and Close or Back) and a page runs to the display's edge.
// On the Duo, folded and open, with or without a title open. A regular
// iPhone and iPad keep their tab bar.

enum TabsLook {
    /// Device-local: the Duo's tabs collapse into the arrow button.
    static let collapsedKey = "v2.shell.collapsedTabs"
    /// The owner kept the look after turning it on (`CollapsedTabsConfirm`).
    static let confirmedKey = "v2.shell.collapsedTabs.confirmed"
    /// The arrow sits at the bottom of the column, where the tabs were
    /// (`CollapsedTabsFloatingButton`), not first in the page's bar.
    static let bottomKey = "v2.shell.collapsedTabs.bottom"

    /// How far down the display the clock, the battery ring and the arrow
    /// button reach (measured on device shots: build 1115, folded 466 x 678
    /// and open 951 x 669). A full-width row starts below this, so its own
    /// trailing buttons never sit under the arrow.
    /// With the arrow at the bottom only the clock and the ring are up there.
    static func clearance(folded: Bool, bottom: Bool = false) -> CGFloat {
        if bottom { return folded ? 168 : 116 }
        return folded ? 232 : 180
    }
}

/// What the tabs' pages need to know about the collapsed column.
struct CollapsedTabsState: Equatable {
    var on = false
    /// The arrow floats at the bottom of the column, not in the page's bar.
    var bottom = false
    /// Activity's badge (what needs you, in v2).
    var activity = 0
    /// Discover's badge (requests that need you).
    var requests = 0
}

extension EnvironmentValues {
    /// Set by `ShellTabs`; off everywhere the tabs are not collapsed.
    @Entry var collapsedTabs = CollapsedTabsState()
}

/// The arrow button, first in the bar: the column's bar grows from it
/// (`ColumnPill`) with the tabs and the page's own buttons (`ColumnAction`).
struct CollapsedTabsItem: ToolbarContent {
    let model: AppModel
    let state: CollapsedTabsState
    let libraryRoot: LibraryTabRootOverride?
    /// The page's own buttons, listed under the tabs.
    var actions: [ColumnAction] = []
    /// A page over the tabs (a title) closes before the tab changes.
    var beforeSwitch: (@MainActor () -> Void)?

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            ColumnArrowButton(state: state, libraryRoot: libraryRoot, actions: actions, beforeSwitch: beforeSwitch)
        }
        .barPriority(true)
    }
}

/// The arrow at the bottom of the Duo's column (owner, build 1129: "an option
/// to move that button at the bottom"): the spot the tabs' pill held, which
/// is free while they are collapsed. The column is the trailing safe-area
/// inset, so the button is centred in it; the pill rises from it.
struct CollapsedTabsFloatingButton: View {
    @Environment(\.columnPill) private var pill
    let model: AppModel
    let state: CollapsedTabsState
    let libraryRoot: LibraryTabRootOverride?
    /// The column's width (the trailing safe-area inset).
    let column: CGFloat
    var actions: [ColumnAction] = []
    var beforeSwitch: (@MainActor () -> Void)?

    private static let side: CGFloat = 50

    var body: some View {
        // A frame, not a filled view: only the button takes touches.
        Group {
            Button {
                pill?.request = ColumnPill.Request(anchor: TouchSpot.last, rises: true, state: state,
                                                   libraryRoot: libraryRoot, actions: actions, beforeSwitch: beforeSwitch)
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                    .frame(width: Self.side, height: Self.side)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Circle())
            .overlay(alignment: .topTrailing) {
                if state.activity > 0 {
                    Circle().fill(Theme.stuck).frame(width: 11, height: 11)
                        .overlay(Circle().strokeBorder(Theme.bg, lineWidth: 2))
                        .offset(x: -2, y: 2)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel(state.activity > 0 ? "Tabs, \(state.activity) in Activity need you" : "Tabs")
            .accessibilityHint(actions.isEmpty ? "Shows the tabs" : "Shows the tabs and this page's buttons")
            .padding(.trailing, max(8, (column - Self.side) / 2))
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        // Into the column, which the tabs' own content keeps clear of.
        .ignoresSafeArea(.container, edges: .trailing)
    }
}

/// Until the owner keeps the look, a way back that doesn't depend on it:
/// if the arrow were missing there would be no route to Account's switch.
struct CollapsedTabsConfirm: ViewModifier {
    @AppStorage(TabsLook.collapsedKey) private var on = false
    @AppStorage(TabsLook.confirmedKey) private var confirmed = false
    @Environment(\.shellChrome) private var chrome
    @Environment(\.horizontalSizeClass) private var sizeClass
    /// The Duo is open (the folded Duo is read from the screen).
    let duoOpen: Bool

    private var duo: Bool { duoOpen || OuterDisplay.isFoldedDuo(sizeClass: sizeClass) }

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if chrome != nil, on, !confirmed, duo {
                HStack(spacing: 10) {
                    Text("Tabs are under the arrow, top right.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.txt)
                        .lineLimit(2)
                    Button("Undo") { on = false }
                        .buttonStyle(.glass)
                    Button("Keep") { confirmed = true }
                        .buttonStyle(.glassProminent)
                        .tint(Theme.indigo)
                }
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: Capsule())
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .transition(.opacity)
            }
        }
    }
}
