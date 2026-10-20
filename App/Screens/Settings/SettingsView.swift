import SwiftUI
import FusionhaKit

/// Settings (`/settings` on the web), presented over the app from the avatar
/// menu. The web's mobile layout is an iOS-style push: a master list (search,
/// General + Metadata, three expandable groups, the collapsible FETCHING and
/// SYSTEM sections) and one full-screen page per panel. Panels are routed by
/// slug through `settingsPanel(_:)`.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var store: SettingsStore
    @State private var flash = SettingsFlash()
    /// The open panel (first slug) and the panels pushed on it. Empty: the
    /// list on a phone, General beside the sidebar.
    @State private var path: [String]
    @State private var query = ""
    /// Groups and sections, all open by default (the web's `openGroups`).
    @State private var closed: Set<String> = []
    /// Settings' own width; `nil` until the first layout.
    @State private var width: CGFloat?
    /// What a collapsed split shows: the list, or the open panel.
    @State private var compactColumn: NavigationSplitViewColumn
    /// The panel pane's frame (global), where the split's toasts sit.
    @State private var paneFrame: CGRect?

    init(client: APIClient?, initialPanel: String? = nil) {
        _store = State(initialValue: SettingsStore(client: client))
        _path = State(initialValue: initialPanel.map { [$0] } ?? [])
        _compactColumn = State(initialValue: initialPanel == nil ? .sidebar : .detail)
    }

    private var motionOff: Bool { reduceMotion || !store.animationsEnabled }

    /// The web's desktop Settings, a sidebar of panels beside the open panel,
    /// from 720 points of Settings' own width (ruling S2), not the size class.
    private var wide: Bool {
        width.map { SettingsSplitRule.splits(width: Double($0)) } ?? (sizeClass == .regular)
    }

    /// One container in every pose (DC16): the split collapses into the
    /// phone's push list and expands again, so folding, unfolding and rotating
    /// keep the list's scroll and the open panel with its focus and typing.
    var body: some View {
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            master
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            NavigationStack(path: detailPath) {
                settingsPanel(path.first ?? "general")
                    .navigationDestination(for: String.self) { slug in
                        settingsPanel(slug)
                    }
            }
            .id(path.first ?? "general")
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { paneFrame = $0 }
        }
        .navigationSplitViewStyle(.balanced)
        // The split view collapses on the size class; ruling S2 puts the
        // break at 720 of the space Settings has, so it is given that one.
        .environment(\.horizontalSizeClass, wide ? .regular : .compact)
        .background {
            Color.clear.onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        }
        .onChange(of: path) { if !path.isEmpty { compactColumn = .detail } }
        .onChange(of: compactColumn) {
            // Back to the list on a phone closes the panel.
            if !wide && compactColumn == .sidebar && !path.isEmpty { path = [] }
        }
        .tint(Theme.indigo)
        .environment(store)
        .environment(flash)
        .environment(\.settingsMotionOff, motionOff)
        .environment(\.settingsPush, push)
        .task { await store.load() }
        .modifier(SettingsShellLink(path: $path, pane: wide ? paneFrame : nil))
    }

    /// The panels pushed on top of the open panel.
    private var detailPath: Binding<[String]> {
        Binding(
            get: { Array(path.dropFirst()) },
            set: { path = [path.first ?? "general"] + $0 }
        )
    }

    private var master: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    SettingsMasterList(selected: wide ? (path.first ?? "general") : nil,
                                       closed: $closed, select: select)
                } else {
                    SettingsSearchResults(query: query, open: open(hit:))
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 64)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Theme.bg)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search settings…")
        .navigationTitle("Settings")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                SheetCancelButton(title: "Close settings") { dismiss() }
            }
        }
    }

    /// The title is the system bar's (D1); the subtitle stays in the page.
    private var header: some View {
        Text("DB-backed · effective without restart")
            .font(.system(size: 15))
            .foregroundStyle(Theme.mut)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, Theme.pageGutter)
            .padding(.top, 8)
            .padding(.bottom, 22)
    }

    // MARK: Navigation

    /// Pushes a panel. In the split, a panel pushed before any sidebar pick
    /// stacks on General, the panel the detail column shows by default.
    private func push(_ slug: String) {
        perform {
            if wide && path.isEmpty { path = ["general"] }
            path.append(slug)
        }
    }

    /// A sidebar / master-list pick opens that panel (on a phone the list
    /// only shows while no panel is open).
    private func select(_ slug: String) {
        perform { path = [slug] }
    }

    private func perform(_ change: () -> Void) {
        if motionOff {
            var t = Transaction(animation: nil)
            t.disablesAnimations = true
            withTransaction(t, change)
        } else {
            change()
        }
    }

    private func open(hit: SettingsSearchHit) {
        query = ""
        flash.set(panel: hit.panel, label: hit.kind == .field ? hit.label : nil)
        select(hit.panel)
    }
}

#if DEBUG
/// CI screenshots: `FUSIONHA_SCREENSHOT_SETTINGS=list` opens Settings at
/// launch; any other value also pushes that panel.
enum SettingsScreenshot {
    static var target: String? { ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_SETTINGS"] }
    static var openAtLaunch: Bool { target != nil }
    static var panel: String? { target.flatMap { $0 == "list" ? nil : $0 } }
}
#else
enum SettingsScreenshot {
    static let openAtLaunch = false
    static let panel: String? = nil
}
#endif
