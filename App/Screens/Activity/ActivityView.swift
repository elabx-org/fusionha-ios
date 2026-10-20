import SwiftUI
import FusionhaKit

enum ActivityTab: String, Hashable {
    case queue, history, wanted, blocklist, tasks, audit, indexers
}

/// Bulk-bar contents published by the tab in select mode, so the glass bar can sit
/// at the bottom of the whole screen.
@MainActor
@Observable
final class ActBulk {
    struct Action: Identifiable {
        let label: String
        var icon: String?
        var kind: ActButtonKind = .ghost
        var disabled = false
        let run: () -> Void
        var id: String { label }
    }

    struct Config {
        var count: Int
        var hint: String?
        var onSelectAll: () -> Void
        var actions: [Action]
    }

    var config: Config?
}

/// Opens Manual import natively (a held-download rescue or the folder scan);
/// "Open on the web" opens the signed-in web page.
@MainActor
@Observable
final class ActRouter {
    var webURL: URL?
    var server: URL?
    /// The held downloads a native Manual import sheet is open for.
    var rescue: ManualImportRequest?

    struct ManualImportRequest: Identifiable {
        let downloadIds: [Int]
        var id: String { downloadIds.map(String.init).joined(separator: ",") }
    }

    func manualImport(rescue downloadId: Int? = nil) {
        manualImport(rescue: downloadId.map { [$0] } ?? [])
    }

    /// A queue rescue (one held download, a season, or every held row) opens
    /// natively as one scan; with no ids it is the native folder scan.
    func manualImport(rescue downloadIds: [Int]) {
        rescue = ManualImportRequest(downloadIds: downloadIds)
    }

    /// The web's Manual import (`/activity?rescue=1,2`), opened signed in.
    func openWeb(rescue downloadIds: [Int]) {
        guard let server else { return }
        var components = URLComponents(url: server.appendingPathComponent("activity"), resolvingAgainstBaseURL: false)
        if !downloadIds.isEmpty {
            components?.queryItems = [URLQueryItem(name: "rescue", value: downloadIds.map(String.init).joined(separator: ","))]
        }
        webURL = components?.url
    }
}

/// The page state the header and the tabs share: the selected tab and the
/// (debounced) title search.
@MainActor
@Observable
final class ActChrome {
    var tab: ActivityTab
    var searchInput = ""
    var search = ""

    /// `?item_id=` (+ `?q=` as its label): History scoped to one title (web `item-filter.ts`).
    var itemFilter: HistoryItemFilter?

    init(tab: ActivityTab) { self.tab = tab }

    var searchable: Bool { tab == .queue || tab == .history || tab == .blocklist || tab == .audit }
}

private struct ActTabsNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    /// Shared by every tab's header so the selected-tab indicator slides between pages.
    var actTabsNamespace: Namespace.ID? {
        get { self[ActTabsNamespaceKey.self] }
        set { self[ActTabsNamespaceKey.self] = newValue }
    }
}

/// The web's Activity page (`routes/Activity.tsx`): header with the live caption
/// and Manual import, the shared title search, and the Queue / History /
/// Blocklist / Tasks / Audit / Indexers tabs.
///
/// Each tab is its own `ActivityPage` (a ScrollView whose LazyVStack holds the
/// header and then the tab's rows as direct children). The page used to be one
/// LazyVStack whose single child was the whole tab, with the rows in a nested
/// LazyVStack: every scroll step then re-measured that one giant child (all
/// visible rows' flow layouts, every frame), which is what made long lists stall.
struct ActivityView: View {
    @Environment(AppModel.self) private var model
    @State private var chrome = ActChrome(tab: ActivityView.initialTab)
    @State private var toaster = ActToaster()
    @State private var bulk = ActBulk()
    @State private var router = ActRouter()
    @State private var animationsEnabled = true
    @Namespace private var tabsNamespace
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private static var initialTab: ActivityTab {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_ACTIVITY_TAB"], let tab = ActivityTab(rawValue: raw) {
            return tab
        }
        #endif
        return .queue
    }

    var body: some View {
        let _ = PerfCount.hit("ActivityView.body")
        Screen {
            switch chrome.tab {
            case .queue: ActivityQueueTab(search: chrome.search)
            case .wanted: WantedView(embedded: true)
            case .history: ActivityHistoryTab(search: chrome.search, itemId: chrome.itemFilter?.itemId)
            case .blocklist: ActivityBlocklistTab(search: chrome.search)
            case .tasks: ActivityTasksTab()
            case .audit: ActivityAuditTab(search: chrome.search)
            case .indexers: ActivityIndexersTab()
            }
        }
        // Toasts go to the shell's host (its placement keeps them off the hinge).
        .onAppear { toaster.shell = model }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let config = bulk.config {
                ActBulkBar(count: config.count, hint: config.hint, onSelectAll: config.onSelectAll) {
                    ForEach(config.actions) { action in
                        Button(action: action.run) {
                            HStack(spacing: 6) {
                                if let icon = action.icon { Image(systemName: icon) }
                                Text(action.label)
                            }
                        }
                        .buttonStyle(ActButtonStyle(kind: action.kind))
                        .disabled(action.disabled)
                    }
                }
            }
        }
        .shellPage("Activity")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Manual import", systemImage: "square.and.arrow.down") { router.manualImport() }
            }
            .barPriority(true)
            if model.me?.isAdmin == true {
                ToolbarItem(placement: .primaryAction) { QueuePauseButton() }
                    .barPriority(false)
            }
        }
        .environment(\.actReduceMotion, systemReduceMotion || !animationsEnabled)
        .environment(\.actTabsNamespace, tabsNamespace)
        .task {
            // The web's global motion switch (`animations_enabled`).
            if let settings = try? await model.client?.activitySettings() {
                animationsEnabled = settings.animationsEnabled ?? true
            }
        }
        .environment(chrome)
        .environment(toaster)
        .environment(bulk)
        .environment(router)
        .sheet(item: $router.webURL) { url in
            // Manual import is the web app's, opened signed in (not Safari, which
            // has no fusionha session and showed the sign-in page).
            FusionhaWebSheet(url: url)
        }
        .sheet(item: $router.rescue) { request in
            ManualImportSheet(downloadIds: request.downloadIds, client: model.client) {
                // After the native sheet closes, open the web version of the same rescue.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    router.openWeb(rescue: request.downloadIds)
                }
            }
            .environment(model)
        }
        .task(id: chrome.searchInput) {
            if chrome.searchInput.isEmpty { chrome.search = ""; return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            chrome.search = chrome.searchInput.trimmingCharacters(in: .whitespaces)
        }
        .onChange(of: chrome.tab) { bulk.config = nil }
        .onChange(of: model.pendingActivityTab, initial: true) {
            // `fusionha://activity/indexers` from the widget.
            guard let tab = model.pendingActivityTab else { return }
            chrome.tab = tab
            model.pendingActivityTab = nil
        }
        .onChange(of: model.pendingHistoryFilter, initial: true) {
            // `fusionha://activity/history?item_id=…&q=…` (an issue thread's History strip).
            guard let filter = model.pendingHistoryFilter else { return }
            model.pendingHistoryFilter = nil
            chrome.itemFilter = filter
            chrome.searchInput = ""
            chrome.tab = .history
        }
        .onChange(of: model.pendingRescueIds, initial: true) {
            guard let ids = model.pendingRescueIds, !ids.isEmpty else { return }
            model.pendingRescueIds = nil
            chrome.tab = .queue
            router.manualImport(rescue: ids)
        }
        .perfActivityTabHook(Binding(get: { chrome.tab }, set: { chrome.tab = $0 }))
        .onAppear { router.server = model.credentials?.serverURL }
    }
}

/// One Activity tab's scrolling page: the shared header, then the tab's content
/// laid out flat (each row a direct child of the lazy stack).
struct ActivityPage<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ActivityPageHeader()
                content
            }
            .padding(.horizontal, Theme.pageGutter)
            .padding(.top, 20)
            .padding(.bottom, Theme.pageBottom)
        }
        .scrollDismissesKeyboard(.immediately)
    }
}
