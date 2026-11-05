import SwiftUI
import FusionhaKit

/// The title's primary actions (mock `acts`): Search missing (Search for a
/// movie) as the one prominent glass button, Interactive search (person),
/// then Monitored on a bookmark. Each runs v1's store action: the same
/// search, the same interactive-search sheet, the same bulk monitor call.
/// With a version card selected both searches name it and run on it alone
/// ("Search 4K", "Search missing 4K"). `stacked` puts Monitored on its own
/// line (the title filling the flat open Duo).
struct V2TitleActionRow: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page
    let detail: ItemDetail
    /// The open Duo's column carries Search in its bar: the row keeps the rest.
    var showsSearch = true
    var height: CGFloat = 42
    /// Monitored on its own line under the searches (the wide page's column).
    var stacked = false
    /// The flip while the PATCH is in flight.
    @State private var monitorOverride: Bool?

    private var canEdit: Bool { model.me?.can("edit") ?? true }
    private var canSearch: Bool { canEdit && (model.me?.can("search") ?? true) }
    private var searching: Bool { store.flash?.phase == .searching }
    private var monitored: Bool { monitorOverride ?? (detail.monitored ?? true) }
    /// The selected version card's version, when the title has more than one.
    private var focused: DetailEdition? { detail.editions.count > 1 ? store.focusedVersion : nil }
    private var searchTitle: String {
        let base = detail.isSeries ? "Search missing" : "Search"
        return focused.map { "\(base) \($0.tier.badgeLetters)" } ?? base
    }

    var body: some View {
        Group {
            if stacked {
                // The wide page's left column (mock `tabWide`): the searches,
                // then Monitored on its own line.
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        searches
                        Spacer(minLength: 0)
                    }
                    monitor
                }
            } else {
                HStack(spacing: 8) {
                    searches
                    monitor
                    Spacer(minLength: 0)
                }
            }
        }
        .v2FadesUnderTitleBar()
        .sensoryFeedback(.selection, trigger: monitored)
        .onChange(of: detail.monitored) { monitorOverride = nil }
    }

    @ViewBuilder
    private var searches: some View {
        if canSearch && showsSearch {
            Button { runSearch() } label: {
                Label(searchTitle, systemImage: "magnifyingglass")
                    .contentTransition(.opacity)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(height: height - 16)
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.i1)
            .symbolEffect(.pulse, options: .repeating, isActive: searching)
            .disabled(searching)
            .accessibilityHint(focused.map { "Searches the \(detail.versionName($0)) version" } ?? "Searches every monitored version")
        }
        if canSearch {
            Button { store.openInteractiveSearch() } label: {
                Image(systemName: "person")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: height - 16, height: height - 16)
            }
            .buttonStyle(.glass)
            .accessibilityLabel(focused.map { "Interactive search, \($0.tier.badgeLetters)" } ?? "Interactive search")
        }
    }

    @ViewBuilder
    private var monitor: some View {
        if canEdit {
            Button { toggleMonitor() } label: {
                Label(monitored ? "Monitored" : "Monitor", systemImage: monitored ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 15, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(height: height - 16)
            }
            .buttonStyle(.glass)
            .foregroundStyle(page?.ink ?? Theme.txt)
            .accessibilityValue(monitored ? "On" : "Off")
        }
    }

    private func runSearch() {
        if let focused {
            let label = "\(detail.title) — \(detail.versionName(focused))"
            Task { await store.search(label: label, editionId: focused.id) }
        } else {
            Task { await store.search(label: "\(detail.title) — all monitored versions") }
        }
    }

    /// The Library's bulk monitor for this one title, then the page reloads.
    private func toggleMonitor() {
        let next = !monitored
        monitorOverride = next
        Task {
            do {
                try await store.client?.bulkMonitor(BulkMonitorRequest(itemIds: [detail.id], monitored: next))
                store.show(next ? "Monitoring \(detail.title)" : "Stopped monitoring \(detail.title)", variant: .success)
                await store.reload()
                await model.loadLibrary()
            } catch {
                monitorOverride = nil
                store.show("Couldn't update \(detail.title)", variant: .error)
            }
        }
    }
}
