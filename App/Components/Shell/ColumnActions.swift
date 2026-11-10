import SwiftUI
import FusionhaKit

// MARK: - The column rule (owner-approved 2026-11-10, option A)
//
// With the tabs collapsed, the Duo's column holds the arrow (every screen,
// the same spot) and Close or Back where there is something to close.
// Every other button a page used to put in the column is handed up as a
// `ColumnAction` and listed under the tabs in the arrow's list, with its
// name. Fewer buttons matter: whatever stays in the column covers the
// trailing end of rows that scroll under it on a full-width page.

/// One of a page's own buttons, for the arrow's list.
struct ColumnAction: Identifiable, Equatable {
    enum Kind {
        case button(@MainActor () -> Void)
        /// A menu of the page's own (it opens as a submenu), or plain
        /// buttons. Nothing with a dialog or sheet attached to itself:
        /// a menu's rows are gone before those could show.
        case control(AnyView)
    }

    let id: String
    var title: String
    var systemImage: String
    var disabled = false
    /// Whatever else the row's look or menu depends on.
    var stamp = ""
    var kind: Kind

    static func button(_ title: String, _ systemImage: String, disabled: Bool = false,
                       _ run: @escaping @MainActor () -> Void) -> ColumnAction {
        ColumnAction(id: title, title: title, systemImage: systemImage, disabled: disabled, kind: .button(run))
    }

    /// A menu (or any labelled control) the page already has.
    static func control<V: View>(_ title: String, stamp: String = "", @ViewBuilder _ view: () -> V) -> ColumnAction {
        ColumnAction(id: title, title: title, systemImage: "", stamp: stamp, kind: .control(AnyView(view())))
    }

    /// Add, where this user may add (as `AddTitleToolbarItem`).
    @MainActor
    static func add(_ model: AppModel) -> ColumnAction? {
        guard !model.requestScoped, model.me?.can("add") != false, !model.selectMode else { return nil }
        return .button("Add", "plus") { model.showingAdd = true }
    }

    // What it shows, not the closures (new on every render).
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.systemImage == rhs.systemImage
            && lhs.disabled == rhs.disabled && lhs.stamp == rhs.stamp
    }
}

/// A title tells the pages pushed over it (a season, an episode) that the
/// column is collapsed, and how to close the title before a tab change.
struct ColumnPage: Equatable {
    var collapsed = false
    var close: (@MainActor () -> Void)?

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.collapsed == rhs.collapsed }
}

extension EnvironmentValues {
    @Entry var columnPage = ColumnPage()
}

struct ColumnActionsKey: PreferenceKey {
    static let defaultValue: [ColumnAction] = []
    static func reduce(value: inout [ColumnAction], nextValue: () -> [ColumnAction]) { value += nextValue() }
}

extension View {
    /// Hands this page's buttons to the arrow's list while `on` (the tabs
    /// are collapsed). Nested content's come first, then the page's.
    func columnActions(_ on: Bool, _ actions: @autoclosure () -> [ColumnAction?]) -> some View {
        let mine = on ? actions().compactMap { $0 } : []
        return transformPreference(ColumnActionsKey.self) { $0 += mine }
    }

    /// The arrow on a page outside the tabs' `ShellPage` (a title, a season,
    /// an episode), with that page's buttons.
    func columnArrow(_ on: Bool, actions: [ColumnAction?] = [], beforeSwitch: (@MainActor () -> Void)? = nil) -> some View {
        modifier(ColumnArrow(on: on, actions: actions.compactMap { $0 }, beforeSwitch: beforeSwitch))
    }
}

/// The page's buttons as the menu's rows, under the tabs.
struct ColumnActionRows: View {
    let actions: [ColumnAction]

    var body: some View {
        ForEach(actions) { action in
            switch action.kind {
            case .button(let run):
                Button(action.title, systemImage: action.systemImage) { run() }
                    .disabled(action.disabled)
            case .control(let view):
                view
            }
        }
    }
}

/// The arrow for a page that isn't a tab's `ShellPage`: first in its bar,
/// or floating at the bottom of the column (Account › Tabs arrow).
private struct ColumnArrow: ViewModifier {
    @Environment(AppModel.self) private var model
    @Environment(\.collapsedTabs) private var tabs
    @Environment(\.libraryTabRoot) private var libraryRoot
    @AppStorage(TabsLook.bottomKey) private var bottom = false
    let on: Bool
    let actions: [ColumnAction]
    let beforeSwitch: (@MainActor () -> Void)?
    @State private var column: CGFloat = 0

    private var state: CollapsedTabsState {
        CollapsedTabsState(on: true, bottom: bottom, activity: tabs.activity, requests: model.requestsBadge)
    }

    func body(content: Content) -> some View {
        content
            .toolbar {
                if on && !bottom {
                    CollapsedTabsItem(model: model, state: state, libraryRoot: libraryRoot, actions: actions,
                                      beforeSwitch: beforeSwitch)
                }
            }
            .overlay {
                if on && bottom {
                    CollapsedTabsFloatingButton(model: model, state: state, libraryRoot: libraryRoot, column: column,
                                                actions: actions, beforeSwitch: beforeSwitch)
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.trailing } action: { if $0 > 0 { column = $0 } }
    }
}
