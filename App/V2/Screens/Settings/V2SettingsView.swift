import SwiftUI
import FusionhaKit

/// v2 Settings (S1, owner-approved 2026-11-04; mock settings-v2.js): on a
/// phone and the folded Duo, the home of hued rows under the server card;
/// on the open Duo, a sidebar of every panel beside the Overview. Download
/// Clients and Indexers are rebuilt in the S1 look (`V2DownloadClientsPanel`,
/// `V2IndexersPanel`); every other panel is v1's (`settingsPanel(_:)`) on
/// its section-tinted ground (`settingsGround`), so every setting,
/// Maintenance › Performance reports included, stays where it was. Same
/// container as v1's `SettingsView`: one split that collapses into the
/// phone's push list, so folding and unfolding keep the open panel.
struct V2SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var store: SettingsStore
    @State private var flash = SettingsFlash()
    @State private var summary = V2SettingsSummary()
    /// The open page (a panel, a group or the Overview) and the panels
    /// pushed on it. Empty: the home on a phone, the Overview when wide.
    @State private var path: [String]
    @State private var query = ""
    @State private var width: CGFloat?
    @State private var compactColumn: NavigationSplitViewColumn
    @State private var paneFrame: CGRect?

    init(client: APIClient?, initialPanel: String? = nil) {
        _store = State(initialValue: SettingsStore(client: client))
        _path = State(initialValue: initialPanel.map { [$0] } ?? [])
        _compactColumn = State(initialValue: initialPanel == nil ? .sidebar : .detail)
    }

    private var motionOff: Bool { reduceMotion || !store.animationsEnabled }

    /// Split from 720 points of Settings' own width, as v1 (ruling S2).
    private var wide: Bool {
        width.map { SettingsSplitRule.splits(width: Double($0)) } ?? (sizeClass == .regular)
    }

    private var root: String { path.first ?? "overview" }

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            master
                .navigationSplitViewColumnWidth(min: 260, ideal: 318, max: 340)
        } detail: {
            NavigationStack(path: detailPath) {
                page(root)
                    .navigationDestination(for: String.self) { slug in page(slug) }
            }
            .id(root)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { paneFrame = $0 }
        }
        .navigationSplitViewStyle(.balanced)
        .environment(\.horizontalSizeClass, wide ? .regular : .compact)
        .background {
            Color.clear.onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        }
        .onChange(of: path) { if !path.isEmpty { compactColumn = .detail } }
        .onChange(of: compactColumn) {
            if !wide && compactColumn == .sidebar && !path.isEmpty { path = [] }
        }
        .tint(Theme.indigo)
        .environment(store)
        .environment(flash)
        .environment(\.settingsMotionOff, motionOff)
        .environment(\.settingsPush, push)
        .environment(\.settingsGround, Self.tintedGround)
        .task { await store.load() }
        .task { await summary.load(model.client) }
        .modifier(SettingsShellLink(path: $path, pane: wide ? paneFrame : nil))
    }

    /// A page by slug: the Overview, a group's list, or a v1 panel.
    @ViewBuilder
    private func page(_ slug: String) -> some View {
        if slug == "overview" {
            V2SettingsOverview(summary: summary, select: select)
        } else if V2SettingsNav.isGroup(slug) {
            V2SettingsGroupPage(id: slug, summary: summary)
        } else {
            switch SettingsNav.canonical(slug) {
            case "clients": V2DownloadClientsPanel()
            case "indexers": V2IndexersPanel()
            default: settingsPanel(slug)
            }
        }
    }

    /// v1 panels' ground in v2: the palette ground with the section tint.
    private static func tintedGround(_ slug: String) -> AnyView {
        AnyView(V2SettingsTintedGround(slug: slug))
    }

    private var detailPath: Binding<[String]> {
        Binding(get: { Array(path.dropFirst()) }, set: { path = [root] + $0 })
    }

    private var master: some View {
        ScrollView {
            if wide {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    V2SettingsSidebar(selected: V2SettingsNav.sidebarSelection(path.first),
                                      summary: summary, select: select)
                } else {
                    SettingsSearchResults(query: query, open: open(hit:))
                        .padding(.horizontal, 8)
                }
            } else {
                V2SettingsHome(summary: summary, query: query, open: select, openHit: open(hit:))
            }
        }
        .contentMargins(.bottom, 64, for: .scrollContent)
        .scrollDismissesKeyboard(.immediately)
        .v2PageGround(art: nil)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search settings")
        .navigationTitle("Settings")
        .toolbarTitleDisplayMode(wide ? .inline : .inlineLarge)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                SheetCancelButton(title: "Close settings") { dismiss() }
            }
        }
    }

    // MARK: Navigation

    /// Pushes a panel; when wide with nothing open it stacks on the Overview.
    private func push(_ slug: String) {
        perform {
            if path.isEmpty { path = [wide ? "overview" : slug] }
            if path.last != slug { path.append(slug) }
        }
    }

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
