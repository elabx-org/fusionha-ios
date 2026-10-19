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

    private var visibleTabs: [ActivityTab] {
        var tabs: [ActivityTab] = [.queue, .history, .wanted, .blocklist, .tasks]
        if model.me?.hasPermission("system.admin") == true { tabs.append(.audit) }
        if model.me?.hasPermission("integrations.manage") == true { tabs.append(.indexers) }
        return tabs
    }

    var body: some View {
        @Bindable var chrome = chrome
        let held = model.queueHeld
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(caption(held: held))
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.mut)
                    .lineLimit(1)
                    .truncationMode(.tail)
                // "Review all N" is Needs you's own outline button now (0.4.198).
                if chrome.searchable {
                    ActSearch(placeholder: chrome.tab == .audit ? "Search titles" : "Search by title…",
                              text: $chrome.searchInput)
                }
                // Ruling A6: mirror the web header's "Resolve all held (N)".
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
