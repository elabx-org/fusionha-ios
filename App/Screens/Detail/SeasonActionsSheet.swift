import SwiftUI
import FusionhaKit

// The season ⋮ sheet: Search / State / View groups for one season.

struct SeasonActionsSheet: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let detail: ItemDetail
    let season: Season

    var body: some View {
        let n = season.seasonNumber
        let editionId = store.scopeEditionId
        let label = store.scopeEditionId == nil ? season.title : "\(season.title) · \(store.actsOnLabel)"
        let monitored = store.seasonMonitored(season)
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text(season.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.txt)
                    .padding(.bottom, 8)

                if model.me?.can("search") ?? true {
                    group("Search")
                    row("magnifyingglass", "Search season", sub: "One decision — prefers a season pack") {
                        dismiss()
                        Task { await store.search(label: label, editionId: editionId, season: n) }
                    }
                    row("text.magnifyingglass", "Search missing episodes",
                        sub: "The gaps only — one at a time, ~\(store.seasonInterval)s apart") {
                        dismiss()
                        Task { await store.gradualSearch(label: label, season: n, editionId: editionId, missingOnly: true) }
                    }
                    row("list.bullet.indent", "Search each episode", sub: "One at a time, ~\(store.seasonInterval)s apart") {
                        dismiss()
                        Task { await store.gradualSearch(label: label, season: n, editionId: editionId, missingOnly: false) }
                    }
                }

                group("State")
                if model.me?.can("edit") ?? true {
                    row(monitored ? "bookmark.fill" : "bookmark", "Monitored", value: monitored ? "On" : "Off") {
                        Task { await store.setSeasonMonitored(n, !monitored) }
                    }
                    row("arrow.clockwise", "Refresh & scan") {
                        dismiss()
                        Task { await store.refreshSeason(n) }
                    }
                }
                let oldest = store.oldestFirst.contains(n)
                row("arrow.up.arrow.down", "Sort", value: oldest ? "Oldest" : "Newest") {
                    if oldest { store.oldestFirst.remove(n) } else { store.oldestFirst.insert(n) }
                }

                group("View")
                row("clock.arrow.circlepath", "Season history") {
                    store.tab = .history
                    dismiss()
                }
            }
            .padding(20)
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.panel)
    }

    private func group(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(Theme.mut)
            .padding(.top, 14)
            .padding(.bottom, 4)
    }

    private func row(_ icon: String, _ title: String, sub: String? = nil, value: String? = nil,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.txt)
                    .frame(width: 34, height: 34)
                    .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                    if let sub { Text(sub).font(.system(size: 12)).foregroundStyle(Theme.mut) }
                }
                Spacer(minLength: 0)
                if let value {
                    Text(value).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.cyan)
                        .contentTransition(.opacity)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
