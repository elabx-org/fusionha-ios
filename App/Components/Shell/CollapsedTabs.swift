import SwiftUI
import FusionhaKit

// MARK: - Collapsed tabs (owner-approved 2026-11-10, v2, on trial)
//
// On the iPhone Duo the system keeps a column on the trailing edge for the
// clock, the page's buttons and the tabs. With this on, the tabs leave the
// column: one arrow button (the first item, so the system puts it in the
// first free spot under the clock) opens them as a menu that drops down
// from it, with the page's own buttons and Account under them, so the column
// holds the arrow (and Close or Back) and a page runs to the display's edge.
// Folded and flat open only; beside an open title the tabs stay in the bar
// under the list pane. A regular iPhone and iPad keep their tab bar.

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

/// The arrow button, first in the bar: it opens the tabs and the page's
/// own buttons (the column rule, `ColumnAction`).
///
/// A system menu, not the popover of build 1129: a page's Filter and More
/// are menus themselves and open here as submenus, and a row that opens a
/// sheet can do so once the menu has gone. In a popover neither worked
/// (one presentation at a time).
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
            Menu {
                CollapsedTabsList(model: model, state: state, libraryRoot: libraryRoot, actions: actions,
                                  beforeSwitch: beforeSwitch)
            } label: {
                Label("Tabs", systemImage: "chevron.down")
            }
            .menuOrder(.fixed)
            // The Activity badge can't be seen while the tabs are closed.
            .badge(state.activity)
            .accessibilityHint(actions.isEmpty ? "Shows the tabs" : "Shows the tabs and this page's buttons")
        }
        .barPriority(true)
    }
}

/// The menu's rows: the tabs (the current one ticked), this page's own
/// buttons, then Account.
struct CollapsedTabsList: View {
    let model: AppModel
    let state: CollapsedTabsState
    let libraryRoot: LibraryTabRootOverride?
    var actions: [ColumnAction] = []
    var beforeSwitch: (@MainActor () -> Void)?

    private struct Entry: Identifiable {
        let tab: AppTab
        let title: String
        let image: String
        var system = false
        var badge = 0
        var id: AppTab { tab }
    }

    private var entries: [Entry] {
        let search = Entry(tab: .search, title: "Search", image: "magnifyingglass", system: true)
        if model.requestScoped {
            return [Entry(tab: .discover, title: "Discover", image: "nav-discover"),
                    Entry(tab: .requests, title: "My requests", image: "nav-requests"),
                    Entry(tab: .you, title: "You", image: "nav-you"), search]
        }
        let library: Entry
        if let title = libraryRoot?.title, let symbol = libraryRoot?.systemImage {
            library = Entry(tab: .library, title: title, image: symbol, system: true)
        } else {
            library = Entry(tab: .library, title: "Library", image: "nav-library")
        }
        return [library,
                Entry(tab: .discover, title: "Discover", image: "nav-discover", badge: state.requests),
                Entry(tab: .calendar, title: "Calendar", image: "nav-calendar"),
                Entry(tab: .activity, title: "Activity", image: "nav-activity", badge: state.activity),
                search]
    }

    private var attention: Bool { model.attentionCount > 0 && !model.requestScoped }

    var body: some View {
        Section {
            ForEach(entries) { entry in
                Toggle(isOn: Binding(get: { model.tab == entry.tab }, set: { _ in open(entry.tab) })) {
                    Label {
                        Text(verbatim: BadgeCount.text(entry.badge).map { "\(entry.title) · \($0)" } ?? entry.title)
                    } icon: {
                        if entry.system { Image(systemName: entry.image) } else { Image(entry.image).renderingMode(.template) }
                    }
                }
            }
        }
        if !actions.isEmpty {
            Section { ColumnActionRows(actions: actions) }
        }
        Section {
            Button(attention ? "Account · \(model.attentionCount) need attention" : "Account",
                   systemImage: "person.crop.circle", action: account)
        }
    }

    private func open(_ tab: AppTab) {
        beforeSwitch?()
        model.tab = tab
    }

    private func account() {
        #if V2
        model.showingAccount = true
        #else
        model.avatar.showingSheet = true
        #endif
    }
}

/// The arrow at the bottom of the Duo's column (owner, build 1129: "an option
/// to move that button at the bottom"): the spot the tabs' pill held, which
/// is free while they are collapsed. The column is the trailing safe-area
/// inset, so the button is centred in it; the menu rises from it.
struct CollapsedTabsFloatingButton: View {
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
            Menu {
                CollapsedTabsList(model: model, state: state, libraryRoot: libraryRoot, actions: actions,
                                  beforeSwitch: beforeSwitch)
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                    .frame(width: Self.side, height: Self.side)
                    .contentShape(Circle())
                    .glassEffect(.regular.interactive(), in: Circle())
            }
            .menuOrder(.fixed)
            .buttonStyle(.plain)
            .overlay(alignment: .topTrailing) {
                if state.activity > 0 {
                    Circle().fill(Theme.stuck).frame(width: 11, height: 11)
                        .overlay(Circle().strokeBorder(Theme.bg, lineWidth: 2))
                        .offset(x: -2, y: 2)
                        .allowsHitTesting(false)
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
