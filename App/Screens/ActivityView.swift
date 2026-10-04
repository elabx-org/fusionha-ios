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

/// The web's Activity page (`routes/Activity.tsx`): header with the live caption
/// and Manual import, the shared title search, and the Queue / History /
/// Blocklist / Tasks / Audit / Indexers tabs.
struct ActivityView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: ActivityTab = ActivityView.initialTab
    @State private var searchInput = ""
    @State private var search = ""
    @State private var toaster = ActToaster()
    @State private var bulk = ActBulk()
    @State private var router = ActRouter()
    @State private var animationsEnabled = true
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private static var initialTab: ActivityTab {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_ACTIVITY_TAB"], let tab = ActivityTab(rawValue: raw) {
            return tab
        }
        #endif
        return .queue
    }

    private var visibleTabs: [ActivityTab] {
        var tabs: [ActivityTab] = [.queue, .history, .blocklist, .tasks]
        if model.me?.hasPermission("system.admin") == true { tabs.append(.audit) }
        if model.me?.hasPermission("integrations.manage") == true { tabs.append(.indexers) }
        return tabs
    }

    private var searchable: Bool { tab == .queue || tab == .history || tab == .blocklist }

    private var heldCount: Int { model.queue.filter { $0.status.lowercased() == "held" }.count }

    var body: some View {
        Screen {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    header
                    ActTabs(items: visibleTabs.map { t in
                        ActTabs<ActivityTab>.Item(value: t, label: label(t),
                                                  badge: t == .queue ? model.queueTotal : 0,
                                                  badgeColor: heldCount > 0 ? Theme.miss : Theme.grab)
                    }, selection: $tab)
                    .padding(.bottom, 20)
                    content
                }
                .padding(.horizontal, 10)
                .padding(.top, 20)
                .padding(.bottom, bulk.config == nil ? 90 : 190)
            }
            .scrollDismissesKeyboard(.immediately)
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
        .task {
            // The web's global motion switch (`animations_enabled`).
            if let settings = try? await model.client?.activitySettings() {
                animationsEnabled = settings.animationsEnabled ?? true
            }
        }
        .environment(toaster)
        .environment(bulk)
        .environment(router)
        .sheet(item: $router.webURL) { url in
            SafariView(url: url).ignoresSafeArea()
        }
        .task(id: searchInput) {
            if searchInput.isEmpty { search = ""; return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            search = searchInput.trimmingCharacters(in: .whitespaces)
        }
        .onChange(of: tab) { bulk.config = nil }
        .onAppear { router.server = model.credentials?.serverURL }
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

    private var caption: String {
        let downloading = max(0, model.queueTotal - heldCount)
        var parts: [String] = []
        if downloading > 0 { parts.append("\(downloading) downloading · live") }
        if heldCount > 0 { parts.append("\(heldCount) need manual import") }
        return parts.isEmpty ? "No active downloads" : parts.joined(separator: " · ")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 14) {
                Text("Activity")
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(Theme.txt)
                    .lineLimit(1)
                    .fixedSize()
                Text(caption)
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
            if searchable {
                ActSearch(placeholder: "Search by title…", text: $searchInput)
            }
        }
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .queue: ActivityQueueTab(search: search)
        case .history: ActivityHistoryTab(search: search)
        case .blocklist: ActivityBlocklistTab(search: search)
        case .tasks: ActivityTasksTab()
        case .audit: ActivityAuditTab()
        case .indexers: ActivityIndexersTab()
        }
    }
}
