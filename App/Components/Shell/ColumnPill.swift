import SwiftUI
import FusionhaKit

// MARK: - The arrow's pill (owner, build 1135: "the expand doesn't expand the bar")
//
// Tapping the arrow grows the column's own bar in place: a glass pill from
// the arrow's spot holding the tabs as icons, then the page's buttons with
// their names beside them, then Account (the approved prototype). Not a
// system menu (build 1135) and not a popover (build 1129): it is drawn in
// the window by `ColumnPillHost`, so a page's Filter or More still open as
// real menus from it and a row can open a sheet (nothing is presented).

/// What the tapped arrow asks the host to show.
@MainActor
@Observable
final class ColumnPill {
    struct Request {
        /// The arrow, in window coordinates (empty when it wasn't measured).
        var anchor: CGRect
        /// The arrow sits at the bottom of the column: the pill rises.
        var rises: Bool
        var state: CollapsedTabsState
        var libraryRoot: LibraryTabRootOverride?
        var actions: [ColumnAction]
        var beforeSwitch: (@MainActor () -> Void)?
    }

    var request: Request?

    func close() { request = nil }
}

extension EnvironmentValues {
    /// The window's (or a sheet's) pill; nil where there is no host.
    @Entry var columnPill: ColumnPill? = nil
}

/// Draws the pill over everything in this window or sheet, bars included.
struct ColumnPillHost: ViewModifier {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pill = ColumnPill()

    func body(content: Content) -> some View {
        content
            .environment(\.columnPill, pill)
            .overlay {
                GeometryReader { proxy in
                    if let request = pill.request {
                        ColumnPillView(model: model, request: request, origin: proxy.frame(in: .global).origin,
                                       size: proxy.size, close: { pill.close() })
                            .transition(.opacity)
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(pill.request != nil)
                .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: pill.request != nil)
            }
            // Whatever a row did, the pill doesn't outlive the page it was opened on.
            .onChange(of: model.tab) { pill.close() }
            .onChange(of: model.presentedItem?.id) { pill.close() }
            .onChange(of: model.showingAdd) { pill.close() }
    }
}

/// The arrow in a bar: it measures itself, so the pill grows from its spot.
struct ColumnArrowButton: View {
    @Environment(\.columnPill) private var pill
    let state: CollapsedTabsState
    let libraryRoot: LibraryTabRootOverride?
    let actions: [ColumnAction]
    let beforeSwitch: (@MainActor () -> Void)?
    @State private var frame: CGRect = .zero

    var body: some View {
        Button {
            pill?.request = ColumnPill.Request(anchor: frame, rises: false, state: state, libraryRoot: libraryRoot,
                                               actions: actions, beforeSwitch: beforeSwitch)
        } label: {
            Label("Tabs", systemImage: "chevron.down")
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
        // The Activity badge can't be seen while the tabs are closed.
        .badge(state.activity)
        .accessibilityHint(actions.isEmpty ? "Shows the tabs" : "Shows the tabs and this page's buttons")
    }
}

/// The scrim and the pill, placed from the arrow's frame.
struct ColumnPillView: View {
    let model: AppModel
    let request: ColumnPill.Request
    /// The host's origin in the window, and its size.
    let origin: CGPoint
    let size: CGSize
    let close: () -> Void

    static let width: CGFloat = 50
    static let row: CGFloat = 42

    private struct Entry: Identifiable {
        let tab: AppTab
        let title: String
        let image: String
        var system = false
        var badge = 0
        var id: AppTab { tab }
    }

    private var entries: [Entry] {
        let state = request.state
        let search = Entry(tab: .search, title: "Search", image: "magnifyingglass", system: true)
        if model.requestScoped {
            return [Entry(tab: .discover, title: "Discover", image: "nav-discover"),
                    Entry(tab: .requests, title: "My requests", image: "nav-requests"),
                    Entry(tab: .you, title: "You", image: "nav-you"), search]
        }
        let library: Entry
        if let title = request.libraryRoot?.title, let symbol = request.libraryRoot?.systemImage {
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

    /// The arrow's centre in the host's space. Unmeasured, the first spot
    /// under the clock and the ring (`TabsLook.clearance`).
    private var centre: CGPoint {
        let a = request.anchor
        if a.width > 0, a.height > 0 { return CGPoint(x: a.midX - origin.x, y: a.midY - origin.y) }
        let folded = size.width < 600
        let y = request.rises ? size.height - 10 - Self.width / 2
                              : TabsLook.clearance(folded: folded, bottom: true) + Self.width / 2
        return CGPoint(x: size.width - (folded ? 47 : 37), y: y)
    }

    var body: some View {
        let c = centre
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.32)
                .contentShape(Rectangle())
                .onTapGesture(perform: close)
                .accessibilityLabel("Close the tabs")
                .accessibilityAddTraits(.isButton)
            column
                .fixedSize()
                .alignmentGuide(.leading) { d in d.width - (c.x + Self.width / 2) }
                .alignmentGuide(.top) { d in
                    request.rises ? d.height - (c.y + Self.width / 2) : -(c.y - Self.width / 2)
                }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private var column: some View {
        VStack(alignment: .trailing, spacing: 0) {
            if !request.rises { arrow }
            ForEach(entries) { entry in
                Button {
                    request.beforeSwitch?()
                    model.tab = entry.tab
                    close()
                } label: {
                    icon(entry)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(entry.badge > 0 ? "\(entry.title), \(entry.badge)" : entry.title)
                .accessibilityAddTraits(model.tab == entry.tab ? [.isButton, .isSelected] : .isButton)
            }
            if !request.actions.isEmpty {
                rule
                ColumnActionRows(actions: request.actions, close: close)
            }
            rule
            Button {
                close()
                #if V2
                model.showingAccount = true
                #else
                model.avatar.showingSheet = true
                #endif
            } label: {
                Label {
                    Text("Account")
                } icon: {
                    Image(uiImage: AccountBarArt.shared.glyph(me: model.me, dot: model.attentionCount > 0 && !model.requestScoped))
                        .renderingMode(.original)
                }
            }
            .buttonStyle(.plain)
            .labelStyle(ColumnRowLabel())
            if request.rises { arrow }
        }
        .padding(.vertical, 2)
        // The bar itself, grown: glass behind the icons' column only.
        .background(alignment: .trailing) {
            Color.clear
                .frame(width: Self.width)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Self.width / 2, style: .continuous))
        }
    }

    /// The arrow's own spot: tapping it again closes the pill.
    private var arrow: some View {
        Button(action: close) {
            Image(systemName: request.rises ? "chevron.down" : "chevron.up")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Theme.txt)
                .frame(width: Self.width, height: Self.width - 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Hide the tabs")
    }

    private var rule: some View {
        Rectangle().fill(Theme.txt.opacity(0.22))
            .frame(width: 24, height: 1)
            .padding(.vertical, 5)
            .padding(.trailing, (Self.width - 24) / 2)
    }

    private func icon(_ entry: Entry) -> some View {
        Group {
            if entry.system { Image(systemName: entry.image) } else { Image(entry.image).renderingMode(.template) }
        }
        .font(.system(size: 21, weight: .medium))
        .foregroundStyle(model.tab == entry.tab ? Theme.primary : Theme.txt)
        .frame(width: Self.width, height: Self.row)
        .overlay(alignment: .topTrailing) {
            if let text = BadgeCount.text(entry.badge) {
                Text(verbatim: text)
                    .font(.system(size: 10, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .frame(minWidth: 16, minHeight: 16)
                    .background(entry.tab == .activity ? Theme.stuck : Theme.primary, in: Capsule())
                    .offset(x: -2, y: 2)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
    }
}

/// The page's buttons under the tabs: each one's name beside its icon.
struct ColumnActionRows: View {
    let actions: [ColumnAction]
    let close: () -> Void

    var body: some View {
        ForEach(actions) { action in
            switch action.kind {
            case .button(let run):
                Button {
                    close()
                    run()
                } label: {
                    Label(action.title, systemImage: action.systemImage)
                }
                .buttonStyle(.plain)
                .disabled(action.disabled)
            case .control(let view):
                view.buttonStyle(.plain)
            }
        }
        .labelStyle(ColumnRowLabel())
        .tint(Theme.txt)
    }
}

/// "Name  [icon]": the icon in the pill, the name on a caption beside it.
struct ColumnRowLabel: LabelStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(Color.black.opacity(0.62), in: Capsule())
            configuration.icon
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(enabled ? Theme.txt : Theme.dim)
                .frame(width: ColumnPillView.width, height: ColumnPillView.row)
        }
        .contentShape(Rectangle())
    }
}
