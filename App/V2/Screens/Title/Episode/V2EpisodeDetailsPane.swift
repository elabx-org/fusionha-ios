import SwiftUI
import FusionhaKit

/// The episode's Details tab (mock browse.js `episodePhone`): the overview,
/// one row of the Monitored pill and the HD | 4K switch, the shown
/// version's file card (or its state when it has no file), the history
/// strip, then Copy path and Delete file. The monitor toggle and the
/// searches are v1's calls.
struct V2EpisodeDetailsPane: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page
    let detail: ItemDetail
    let episode: Episode
    let seasonNumber: Int
    let version: DetailEdition?
    @Binding var versionId: Int

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let text = episode.overview, !text.isEmpty {
                Text(text)
                    .font(.system(size: 14.5))
                    .lineSpacing(3)
                    .foregroundStyle(ink.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
                    .readableWidth()
            }
            monitoredRow
            if let version {
                fileSection(version)
                V2EpisodeHistoryStrip(detail: detail, episode: episode, seasonNumber: seasonNumber, version: version)
                if let file = episode.file(for: version.id) {
                    V2EpisodeFileActions(version: version, file: file)
                        .padding(.top, 6)
                }
            }
        }
    }

    /// The Monitored pill (bookmark, never a checkmark), the version switch on the right.
    private var monitoredRow: some View {
        let on = store.episodeMonitored(episode)
        return HStack(spacing: 10) {
            Button {
                Task { await store.setEpisodeMonitored(episode, seasonNumber: seasonNumber, !on) }
            } label: {
                Label(on ? "Monitored" : "Not monitored", systemImage: on ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 14.5, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(ink)
                    .frame(height: 42)
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.glass)
            .disabled(!(model.me?.can("edit") ?? true))
            .accessibilityAddTraits(.isToggle)
            .accessibilityLabel("Monitored")
            .accessibilityValue(on ? "On" : "Off")
            Spacer(minLength: 8)
            V2EpisodeVersionPicker(editions: detail.orderedEditions, selection: $versionId)
        }
    }

    private func fileSection(_ version: DetailEdition) -> some View {
        let file = episode.file(for: version.id)
        return VStack(alignment: .leading, spacing: 10) {
            V2TitleSectionHead(title: "File", detail: "\(version.label) · \(file == nil ? "not on disk" : "on disk")",
                               top: 0)
            if let file {
                V2EpisodeFileCard(version: version, file: file,
                                  monitored: store.editionMonitored(version) && store.episodeMonitored(episode))
            } else {
                V2EpisodeNoFileCard(detail: detail, episode: episode, seasonNumber: seasonNumber, version: version)
            }
        }
    }
}

/// HD | 4K, when the title has more than one version (mock `edSeg`).
struct V2EpisodeVersionPicker: View {
    let editions: [DetailEdition]
    @Binding var selection: Int

    var body: some View {
        if editions.count > 1 {
            Picker("Version", selection: $selection) {
                ForEach(editions) { edition in
                    Text(edition.versionKey.isEmpty ? edition.tier.badgeLetters : edition.label).tag(edition.id)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
        }
    }
}

/// A version with no file for this episode: its badge, what is happening,
/// and its own searches.
private struct V2EpisodeNoFileCard: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page
    let detail: ItemDetail
    let episode: Episode
    let seasonNumber: Int
    let version: DetailEdition

    private var canSearch: Bool { (model.me?.can("edit") ?? true) && (model.me?.can("search") ?? true) }

    var body: some View {
        let state = V2TitleNextUp.state(episode, edition: version, now: Date())
        let download = episode.download(for: version.id)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                EditionBadge(tier: version.tier, state: state)
                Text(line(state))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(state.isHeld ? Theme.stuck : (page?.ink ?? Theme.txt))
            }
            if let title = download?.releaseTitle {
                Text(title)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .lineLimit(2)
            }
            if canSearch {
                HStack(spacing: 8) {
                    Button("Search \(version.tier.badgeLetters)", systemImage: "magnifyingglass") {
                        let code = EpisodeCode.episode(season: seasonNumber, episode: episode.episodeNumber)
                        Task { await store.search(label: "\(detail.title) \(code) · \(version.label)", editionId: version.id,
                                                  episodeId: episode.id) }
                    }
                    Button("Choose", systemImage: "person") {
                        store.interactive = InteractiveTarget(editionIds: [version.id], episodeId: episode.id,
                                                              subtitle: "S\(seasonNumber)·E\(episode.episodeNumber)")
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .buttonStyle(.glass)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { ModuleSurface(radius: 20) }
    }

    private func line(_ state: EditionBadgeState) -> String {
        switch episode.status(editionId: version.id) {
        case .downloading, .upgrading:
            return episode.download(for: version.id)?.progress.map { "Downloading \(Int($0.rounded()))%" } ?? "Downloading"
        case .stuck, .attention: return "Held · needs you"
        case .soon: return V2TitleNextUp.when(episode, aired: false) ?? "Not aired yet"
        default: return V2TitleNextUp.when(episode, aired: true).map { "Missing · \($0.lowercased())" } ?? "Missing"
        }
    }
}
