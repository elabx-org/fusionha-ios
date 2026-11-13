import SwiftUI
import FusionhaKit

/// The title's primary actions (mock `acts`): Search missing (Search for a
/// movie) as the one prominent glass button, then Interactive search
/// (person). Each runs v1's store action: the same search, the same interactive-search
/// sheet. Monitor is the bookmark after the title (`V2TitleMonitorBookmark`).
/// With a version card selected both searches name it and run on it alone
/// ("Search 4K", "Search missing 4K").
struct V2TitleActionRow: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    /// The open Duo's column carries Search in its bar: the row keeps the rest.
    var showsSearch = true
    var height: CGFloat = 42

    private var canEdit: Bool { model.me?.can("edit") ?? true }
    private var canSearch: Bool { canEdit && (model.me?.can("search") ?? true) }
    private var target: SearchTarget { focused.map { .version($0.id) } ?? .title }
    private var activity: SearchActivity? { store.activity(target) }
    /// The selected version card's version, when the title has more than one.
    private var focused: DetailEdition? { detail.editions.count > 1 ? store.focusedVersion : nil }
    private var searchTitle: String {
        let base = detail.isSeries ? "Search missing" : "Search"
        return focused.map { "\(base) \($0.tier.badgeLetters)" } ?? base
    }

    var body: some View {
        HStack(spacing: 8) {
            searches
            Spacer(minLength: 0)
        }
        .v2FadesUnderTitleBar()
    }

    @ViewBuilder
    private var searches: some View {
        if canSearch && showsSearch {
            Button { runSearch() } label: {
                V2SearchLabel(title: searchTitle, activity: activity, spinner: Theme.onAccent)
                    // The page ink (dark in Daylight) otherwise wins over the
                    // prominent style's own text colour.
                    .foregroundStyle(Theme.onAccent)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(height: height - 16)
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.i1)
            // Searching is the active state: the fill stays indigo (a disabled
            // prominent button greys out and hides the spinner); taps are off.
            .allowsHitTesting(activity?.isSearching != true)
            .accessibilityAddTraits(activity?.isSearching == true ? .updatesFrequently : [])
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

    private func runSearch() {
        if let focused {
            store.v2Search(target, label: "\(detail.title) — \(detail.versionName(focused))", editionId: focused.id)
        } else {
            store.v2Search(target, label: "\(detail.title) — all monitored versions")
        }
    }
}
