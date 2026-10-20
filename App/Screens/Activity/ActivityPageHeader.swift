import SwiftUI
import FusionhaKit

/// The header (live caption, search) and the tab strip; the title, Manual
/// import and Pause are in the system bar (`ActivityToolbar`, D1). Reads the
/// polled queue counts itself, so a queue tick re-renders only this.
struct ActivityPageHeader: View {
    @Environment(AppModel.self) private var model
    @Environment(ActChrome.self) private var chrome
    @Environment(ActRouter.self) private var router
    @Environment(\.actTabsNamespace) private var tabsNamespace
    @Environment(\.paneSize) private var pane

    private var visibleTabs: [ActivityTab] {
        var tabs: [ActivityTab] = [.queue, .history, .wanted, .blocklist, .tasks]
        if model.me?.hasPermission("system.admin") == true { tabs.append(.audit) }
        if model.me?.hasPermission("integrations.manage") == true { tabs.append(.indexers) }
        return tabs
    }

    var body: some View {
        let held = model.queueHeld
        @Bindable var chrome = chrome
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if pane.isDesktopPane {
                    // Desktop (web `Activity.module.css` .head above 720): one row,
                    // the caption, then the search (200–340) and Resolve all held.
                    HStack(spacing: 14) {
                        captionText(held: held)
                        Spacer(minLength: 0)
                        search.frame(minWidth: 200, maxWidth: 340)
                        resolveHeld(held)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        captionText(held: held)
                        search
                        resolveHeld(held)
                    }
                }
            }
            .padding(.bottom, 20)
            ActTabs(items: visibleTabs.map { t in
                ActTabs<ActivityTab>.Item(value: t, label: label(t),
                                          badge: t == .queue ? model.queueTotal : 0,
                                          badgeColor: held > 0 ? Theme.miss : Theme.grab,
                                          badgeInk: Theme.onFill(hex: held > 0 ? Theme.palette.miss : Theme.palette.grab))
            }, selection: $chrome.tab, namespace: tabsNamespace)
            .padding(.bottom, 20)
        }
    }

    private func captionText(held: Int) -> some View {
        Text(caption(held: held))
            .font(.system(size: 15))
            .foregroundStyle(Theme.mut)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    // "Review all N" is Needs you's own outline button now (0.4.198).
    @ViewBuilder private var search: some View {
        @Bindable var chrome = chrome
        if chrome.searchable {
            ActSearch(placeholder: chrome.tab == .audit ? "Search titles" : "Search by title…",
                      text: $chrome.searchInput)
        }
    }

    /// Ruling A6: mirror the web header's "Resolve all held (N)".
    @ViewBuilder private func resolveHeld(_ held: Int) -> some View {
        if held > 0 {
            Button {
                router.manualImport(rescue: model.queueHeldIds)
            } label: {
                Label("Resolve all held (\(held))", systemImage: "square.and.arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .glassControl()
            .fixedSize()
        }
    }

    private func label(_ t: ActivityTab) -> String {
        switch t {
        case .queue: return "Queue"
        case .wanted: return "Wanted"
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
