import SwiftUI
import FusionhaKit

/// The episode's Details tab: the overview (when there is one), Monitored as
/// a bookmark toggle with the status of each scoped version that has no file
/// yet, then one card per owned file in the Files tab's style
/// (`EpisodeFileCard`).
struct EpisodeDetailsPane: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    let episode: Episode
    let seasonNumber: Int

    var body: some View {
        let versions = store.scopedEditions
        VStack(alignment: .leading, spacing: 16) {
            if let overview = episode.overview, !overview.isEmpty {
                Text(overview)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.txt)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .readableWidth()
            }
            VStack(spacing: 0) {
                monitoredRow
                ForEach(versions.filter { episode.file(for: $0.id) == nil }) { version in
                    statusRow(version)
                }
            }
            .detailCard(radius: 14, shadow: false)
            ForEach(versions) { version in
                if let file = episode.file(for: version.id) {
                    EpisodeFileCard(version: version, file: file,
                                    monitored: store.editionMonitored(version) && store.episodeMonitored(episode))
                }
            }
        }
    }

    /// Monitored: the bookmark (filled when on) and a toggle wired to the
    /// row's own monitor action. Read-only visitors see it disabled.
    private var monitoredRow: some View {
        let on = store.episodeMonitored(episode)
        let binding = Binding(
            get: { store.episodeMonitored(episode) },
            set: { value in Task { await store.setEpisodeMonitored(episode, seasonNumber: seasonNumber, value) } }
        )
        return Toggle(isOn: binding) {
            Label {
                Text("Monitored").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.txt)
            } icon: {
                Image(systemName: on ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(on ? Theme.i1 : Theme.dim)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .tint(Theme.indigo)
        .disabled(!(model.me?.can("edit") ?? true))
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
    }

    /// A version with no file for this episode: its chip and status.
    private func statusRow(_ version: DetailEdition) -> some View {
        HStack {
            DetailTierChip(tier: version.tier, label: version.label)
            Spacer(minLength: 8)
            EpisodeStatusChip(episode: episode, edition: version)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1).padding(.leading, 14) }
    }
}
