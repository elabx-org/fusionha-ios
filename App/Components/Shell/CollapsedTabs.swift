import SwiftUI
import FusionhaKit

// MARK: - Collapsed tabs (owner-approved 2026-11-10, v2, on trial)
//
// On the iPhone Duo the system keeps a column on the trailing edge for the
// clock, the page's buttons and the tabs. With this on, the tabs leave the
// column: one arrow button (the first item, so the system puts it in the
// first free spot under the clock) opens them as a short list that drops
// down from it. Account moves into that list too, so the column holds one
// button and a page can run its content to the display's edge (Search does).
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

/// The arrow button, first in the bar: it opens the tabs.
struct CollapsedTabsItem: ToolbarContent {
    let model: AppModel
    let state: CollapsedTabsState
    let libraryRoot: LibraryTabRootOverride?
    @Binding var open: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { open = true } label: {
                Label("Tabs", systemImage: "chevron.down")
            }
            // The Activity badge can't be seen while the tabs are closed.
            .badge(state.activity)
            .accessibilityHint("Shows the tabs")
            .popover(isPresented: $open) {
                CollapsedTabsList(model: model, state: state, libraryRoot: libraryRoot) { open = false }
                    .presentationCompactAdaptation(.popover)
            }
        }
        .barPriority(true)
    }
}

/// The tabs as a short column of icons, the current one in the accent, then
/// Account. Controls, so the system's popover glass carries them.
struct CollapsedTabsList: View {
    let model: AppModel
    let state: CollapsedTabsState
    let libraryRoot: LibraryTabRootOverride?
    let close: () -> Void

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

    private var dot: Bool { model.attentionCount > 0 && !model.requestScoped }

    var body: some View {
        VStack(spacing: 2) {
            ForEach(entries) { entry in
                Button {
                    model.tab = entry.tab
                    close()
                } label: {
                    icon(entry)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(entry.badge > 0 ? "\(entry.title), \(entry.badge)" : entry.title)
                .accessibilityAddTraits(model.tab == entry.tab ? [.isButton, .isSelected] : .isButton)
            }
            Divider().frame(width: 26).padding(.vertical, 4)
            Button(action: account) {
                Image(uiImage: AccountBarArt.shared.glyph(me: model.me, dot: dot))
                    .renderingMode(.original)
                    .frame(width: 48, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(dot ? "Account, \(model.attentionCount) need attention" : "Account")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
    }

    private func icon(_ entry: Entry) -> some View {
        Group {
            if entry.system { Image(systemName: entry.image) } else { Image(entry.image).renderingMode(.template) }
        }
        .font(.system(size: 21, weight: .medium))
        .foregroundStyle(model.tab == entry.tab ? Theme.primary : Theme.txt)
        .frame(width: 48, height: 44)
        .overlay(alignment: .topTrailing) {
            if let text = BadgeCount.text(entry.badge) {
            Text(verbatim: text)
                .font(.system(size: 10, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .frame(minWidth: 16, minHeight: 16)
                .background(entry.tab == .activity ? Theme.stuck : Theme.primary, in: Capsule())
                .offset(x: 2, y: 2)
                .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
    }

    /// Account opens once the list has gone (one presentation at a time).
    private func account() {
        close()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            #if V2
            model.showingAccount = true
            #else
            model.avatar.showingSheet = true
            #endif
        }
    }
}

/// The arrow at the bottom of the Duo's column (owner, build 1129: "an option
/// to move that button at the bottom"): the spot the tabs' pill held, which
/// is free while they are collapsed. The column is the trailing safe-area
/// inset, so the button is centred in it; the tabs rise from it.
struct CollapsedTabsFloatingButton: View {
    let model: AppModel
    let state: CollapsedTabsState
    let libraryRoot: LibraryTabRootOverride?
    /// The column's width (the trailing safe-area inset).
    let column: CGFloat
    @State private var open = false

    private static let side: CGFloat = 50

    var body: some View {
        // A frame, not a filled view: only the button takes touches.
        Group {
            Button { open = true } label: {
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
            .accessibilityHint("Shows the tabs")
            .popover(isPresented: $open, arrowEdge: .bottom) {
                CollapsedTabsList(model: model, state: state, libraryRoot: libraryRoot) { open = false }
                    .presentationCompactAdaptation(.popover)
            }
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
