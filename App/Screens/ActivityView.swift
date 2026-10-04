import SwiftUI
import FusionhaKit

enum ActivityTab: String, Hashable {
    case queue, history, blocklist, tasks, audit, indexers
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

/// Opens web-only flows (Manual import) in an in-app Safari sheet.
@MainActor
@Observable
final class ActRouter {
    var webURL: URL?
    var server: URL?

    /// The web's Manual import modal is a large flow (scan, per-file overrides,
    /// import mode); it opens as the web page. `rescue` pre-scopes it to a held download.
    func manualImport(rescue downloadId: Int? = nil) {
        guard let server else { return }
        var components = URLComponents(url: server.appendingPathComponent("activity"), resolvingAgainstBaseURL: false)
        if let downloadId { components?.queryItems = [URLQueryItem(name: "rescue", value: "\(downloadId)")] }
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

    init(tab: ActivityTab) { self.tab = tab }

    var searchable: Bool { tab == .queue || tab == .history || tab == .blocklist }
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
            case .history: ActivityHistoryTab(search: chrome.search)
            case .blocklist: ActivityBlocklistTab(search: chrome.search)
            case .tasks: ActivityTasksTab()
            case .audit: ActivityAuditTab()
            case .indexers: ActivityIndexersTab()
            }
        }
        .overlay { ActToastOverlay(toaster: toaster).padding(.bottom, 70) }
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
            SafariView(url: url).ignoresSafeArea()
        }
        .task(id: chrome.searchInput) {
            if chrome.searchInput.isEmpty { chrome.search = ""; return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            chrome.search = chrome.searchInput.trimmingCharacters(in: .whitespaces)
        }
        .onChange(of: chrome.tab) { bulk.config = nil }
        .perfActivityTabHook(Binding(get: { chrome.tab }, set: { chrome.tab = $0 }))
        .onAppear { router.server = model.credentials?.serverURL }
    }
}

/// One Activity tab's scrolling page: the shared header, then the tab's content
/// laid out flat (each row a direct child of the lazy stack).
struct ActivityPage<Content: View>: View {
    @Environment(ActBulk.self) private var bulk
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ActivityPageHeader()
                content
            }
            .padding(.horizontal, 10)
            .padding(.top, 20)
            .padding(.bottom, bulk.config == nil ? 90 : 190)
        }
        .scrollDismissesKeyboard(.immediately)
    }
}

/// The header (title, live caption, Manual import, search) and the tab strip.
/// Reads the polled queue counts itself, so a queue tick re-renders only this.
struct ActivityPageHeader: View {
    @Environment(AppModel.self) private var model
    @Environment(ActChrome.self) private var chrome
    @Environment(ActRouter.self) private var router
    @Environment(\.actTabsNamespace) private var tabsNamespace

    private var visibleTabs: [ActivityTab] {
        var tabs: [ActivityTab] = [.queue, .history, .blocklist, .tasks]
        if model.me?.hasPermission("system.admin") == true { tabs.append(.audit) }
        if model.me?.hasPermission("integrations.manage") == true { tabs.append(.indexers) }
        return tabs
    }

    var body: some View {
        @Bindable var chrome = chrome
        let held = model.queueHeld
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 14) {
                    Text("Activity")
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.3)
                        .foregroundStyle(Theme.txt)
                        .lineLimit(1)
                        .fixedSize()
                    Text(caption(held: held))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.mut)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                    Button {
                        router.manualImport()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.txt)
                            .frame(width: 30, height: 30)
                            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.line))
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, -5)
                    .padding(.trailing, -5)
                    .accessibilityLabel("Manual import")
                }
                if chrome.searchable {
                    ActSearch(placeholder: "Search by title…", text: $chrome.searchInput)
                }
            }
            .padding(.bottom, 20)
            ActTabs(items: visibleTabs.map { t in
                ActTabs<ActivityTab>.Item(value: t, label: label(t),
                                          badge: t == .queue ? model.queueTotal : 0,
                                          badgeColor: held > 0 ? Theme.miss : Theme.grab)
            }, selection: $chrome.tab, namespace: tabsNamespace)
            .padding(.bottom, 20)
        }
    }

    private func label(_ t: ActivityTab) -> String {
        switch t {
        case .queue: return "Queue"
        case .history: return "History"
        case .blocklist: return "Blocklist"
        case .tasks: return "Tasks"
        case .audit: return "Audit"
        case .indexers: return "Indexers"
        }
    }

    private func caption(held: Int) -> String {
        let downloading = max(0, model.queueTotal - held)
        var parts: [String] = []
        if downloading > 0 { parts.append("\(downloading) downloading · live") }
        if held > 0 { parts.append("\(held) need manual import") }
        return parts.isEmpty ? "No active downloads" : parts.joined(separator: " · ")
    }
}
