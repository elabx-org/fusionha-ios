import SwiftUI
import FusionhaKit

// MARK: - The arrow's pill (owner, build 1135: "the expand doesn't expand the bar")
//
// Tapping the arrow grows the column's own bar in place: a glass pill from
// the arrow's spot holding the tabs, the page's buttons and Account, all
// as icons; the page under it still scrolls. Not a
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
    /// The host's own view, to place the pill from window coordinates.
    @ObservationIgnored weak var probe: TouchSpotProbe.ProbeView?

    func close() { request = nil }

    /// The display changed size under an open pill (a fold or an unfold):
    /// it was left where the arrow had been, in the middle of the new
    /// display (owner, build 1146). It goes at once, and comes back on the
    /// arrow's new spot once the bar has settled, if the arrow can be found.
    func resized() {
        guard let old = request else { return }
        request = nil
        // The floating arrow (Tabs arrow: Bottom) isn't a bar item: closed.
        guard !old.rises else { return }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard let self, self.request == nil, let window = self.probe?.window,
                  let frame = TouchSpot.barItem(labelled: "Tabs", in: window) else { return }
            var next = old
            next.anchor = frame
            self.request = next
        }
    }
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
                    Color.clear.onChange(of: proxy.size) { pill.resized() }
                    if let request = pill.request {
                        ColumnPillView(model: model, request: request, origin: pill.probe?.windowOrigin ?? .zero,
                                       size: proxy.size, close: { pill.close() })
                            .transition(.opacity)
                    }
                }
                .background { TouchSpotProbe { pill.probe = $0 }.allowsHitTesting(false) }
                .ignoresSafeArea()
                .allowsHitTesting(pill.request != nil)
                .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: pill.request != nil)
            }
            // Whatever a row did, the pill doesn't outlive the page it was opened on.
            .onChange(of: model.tab) { pill.close() }
            // Scrolling the page closes it (owner, build 1139).
            .onReceive(NotificationCenter.default.publisher(for: .touchSpotDragged)) { _ in
                if pill.request != nil { pill.close() }
            }
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

    var body: some View {
        Button {
            // The bar item just touched, in the window (`TouchSpot`).
            pill?.request = ColumnPill.Request(anchor: TouchSpot.last, rises: false, state: state,
                                               libraryRoot: libraryRoot, actions: actions, beforeSwitch: beforeSwitch)
        } label: {
            Label("Tabs", systemImage: "chevron.down")
        }
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
        // From the trailing corner: the pill's trailing edge is the arrow's,
        // its top (or, rising, its bottom) the arrow's.
        let inset = max(0, size.width - (c.x + Self.width / 2))
        // No scrim: the page under the open pill still scrolls and takes
        // taps (owner, build 1139). An empty frame passes touches through.
        column
            .fixedSize()
            .padding(.trailing, inset)
            .padding(request.rises ? .bottom : .top,
                     max(0, request.rises ? size.height - (c.y + Self.width / 2) : c.y - Self.width / 2))
            .frame(width: size.width, height: size.height, alignment: request.rises ? .bottomTrailing : .topTrailing)
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
            .accessibilityLabel(model.attentionCount > 0 && !model.requestScoped
                                ? "Account, \(model.attentionCount) need attention" : "Account")
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

/// The page's buttons under the tabs, as icons.
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
                .accessibilityLabel(action.title)
            case .control(let view):
                view.buttonStyle(.plain).accessibilityLabel(action.title)
            }
        }
        .labelStyle(ColumnRowLabel())
        .tint(Theme.txt)
    }
}

/// A page button's row: its icon alone, as the tabs' (owner, build 1139).
/// The name stays for VoiceOver (`ColumnActionRows`).
struct ColumnRowLabel: LabelStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.icon
            .font(.system(size: 19, weight: .medium))
            .foregroundStyle(enabled ? Theme.txt : Theme.dim)
            .frame(width: ColumnPillView.width, height: ColumnPillView.row)
            .contentShape(Rectangle())
    }
}
