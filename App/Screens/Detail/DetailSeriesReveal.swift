import SwiftUI
import FusionhaKit

// The series reveals (EditionCoverage.tsx): one tier (D.6), all editions
// without versions (D.7) and the versions × tiers matrix (D.8).

private func seriesState(_ cover: Cover, upgrading: Bool) -> DetailStatePillKind {
    if upgrading { return .upgrading }
    switch cover.state {
    case .done: return .ok("Complete")
    case .part: return cover.grabbing > 0 ? .part("Downloading \(cover.grabbing)") : .part("\(cover.owned)/\(cover.total)")
    case .empty: return cover.total == 0 ? .soon : .want
    }
}

/// The latest regular season (Specials only when nothing else exists).
private func defaultSeason(_ detail: ItemDetail) -> Int? {
    let numbers = (detail.seasons ?? []).map(\.seasonNumber)
    return numbers.filter { $0 > 0 }.max() ?? numbers.max()
}

// MARK: - D.6 scoped series

struct ScopedSeriesReveal: View {
    @Environment(DetailStore.self) private var store
    let detail: ItemDetail
    let edition: DetailEdition
    @State private var selected: Int?

    var body: some View {
        let cover = detail.cover(edition: edition)
        let tierColor = DetailTokens.tier(edition.tier)
        VStack(alignment: .leading, spacing: 0) {
            RevealHeader(label: edition.label, count: detail.coverageText(edition),
                         state: seriesState(cover, upgrading: edition.downloadState == "upgrading"),
                         detail: detail, railEdition: edition) {
                DetailDot(color: Theme.txt, size: 9)
            }

            VStack(alignment: .leading, spacing: 10) {
                DetailCoverageBar(total: cover.total, owned: cover.owned, grabbing: cover.grabbing, color: tierColor)
                legend(cover)
                SeasonChipGrid(detail: detail, editions: [edition], selected: selectedBinding,
                               label: "Seasons · tap to inspect episodes")
                if let season = currentSeason {
                    DrillBox(detail: detail, season: season, editions: [edition])
                }
            }
            .padding(.horizontal, 15)
            .padding(.bottom, 15)

            metaGrid
            fileLine(cover)
        }
    }

    private var selectedBinding: Binding<Int?> {
        Binding(get: { selected ?? defaultSeason(detail) }, set: { selected = $0 })
    }

    private var currentSeason: Season? {
        let n = selected ?? defaultSeason(detail)
        return detail.seasons?.first { $0.seasonNumber == n }
    }

    private func legend(_ cover: Cover) -> some View {
        let seasons = detail.seasons ?? []
        let complete = seasons.filter { $0.cover(editionId: edition.id).state == .done }.count
        return FlowRow(spacing: 12, lineSpacing: 4) {
            legendItem("Owned", cover.owned)
            if cover.grabbing > 0 { legendItem("Grabbing", cover.grabbing) }
            legendItem("Wanted", cover.wanted)
            if cover.kept > 0 { legendItem("Kept", cover.kept) }
            if cover.untracked > 0 { legendItem("Not tracked", cover.untracked) }
            Text("·").foregroundStyle(Theme.mut)
            (Text("\(complete)").fontWeight(.bold).foregroundColor(Theme.txt) + Text(" of ")
                + Text("\(seasons.count)").fontWeight(.bold).foregroundColor(Theme.txt) + Text(" seasons"))
        }
        .font(.system(size: 11))
        .foregroundStyle(Theme.mut)
    }

    private func legendItem(_ label: String, _ n: Int) -> Text {
        Text(label + " ") + Text("\(n)").fontWeight(.bold).foregroundColor(Theme.txt)
    }

    private var metaGrid: some View {
        let monitored = store.editionMonitored(edition)
        let cutoff = store.cutoff(edition.qualityProfileId)
        return VStack(spacing: 1) {
            HStack(spacing: 1) {
                DetailMetaCell(key: "Root folder", value: store.rootPath(edition))
                DetailMetaCell(key: "Quality profile", value: store.profileName(edition.qualityProfileId))
            }
            HStack(spacing: 1) {
                DetailMetaCell(key: "Cutoff", value: cutoff.map { DetailText.quality($0) } ?? "—")
                DetailMetaCell(key: "Monitoring", value: monitored ? "Monitored" : "Not monitored",
                         valueColor: monitored ? Theme.cyan : Theme.mut)
            }
        }
        .background(Theme.line)
        .padding(.top, 1)
        .background(Theme.line)
    }

    private func fileLine(_ cover: Cover) -> some View {
        let owned = detail.fileCount(edition)
        return (Text("Files ") + Text("\(owned)/\(detail.allEpisodes.count) episodes · \(DetailText.bytes(detail.editionBytes(edition)))")
            .fontWeight(.bold).foregroundColor(Theme.txt))
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(Theme.mut)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .background(Theme.panel2)
            .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}

// MARK: - D.7 series All

struct SeriesAllReveal: View {
    let detail: ItemDetail
    let editions: [DetailEdition]
    @State private var selected: Int?

    var body: some View {
        let covers = editions.map { detail.cover(edition: $0) }
        let total = covers.reduce(Cover(), +)
        let state: DetailStatePillKind = covers.allSatisfy { $0.state == .done } && !covers.isEmpty ? .ok("Complete")
            : seriesState(total, upgrading: editions.contains { $0.downloadState == "upgrading" })
        VStack(alignment: .leading, spacing: 0) {
            RevealHeader(label: "All editions", state: state, detail: detail, railEdition: nil) { DetailDualDots() }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(editions.indices, id: \.self) { i in
                    let edition = editions[i], cover = covers[i]
                    HStack(spacing: 10) {
                        Text(edition.versionKey.isEmpty ? edition.tier.chipLabel : edition.label)
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(DetailTokens.tier(edition.tier))
                            .lineLimit(1)
                            .frame(minWidth: 64, alignment: .leading)
                        DetailCoverageBar(total: cover.total, owned: cover.owned, grabbing: cover.grabbing,
                                    color: DetailTokens.tier(edition.tier), height: 6)
                        Text("\(cover.owned)/\(cover.total)")
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundStyle(Theme.mut)
                    }
                }
                SeasonChipGrid(detail: detail, editions: editions, selected: selectedBinding,
                               label: "Seasons · HD over 4K · tap to inspect episodes")
                if let season = currentSeason {
                    DrillBox(detail: detail, season: season, editions: editions)
                }
            }
            .padding(.horizontal, 15)
            .padding(.bottom, 15)
        }
    }

    private var selectedBinding: Binding<Int?> {
        Binding(get: { selected ?? defaultSeason(detail) }, set: { selected = $0 })
    }

    private var currentSeason: Season? {
        let n = selected ?? defaultSeason(detail)
        return detail.seasons?.first { $0.seasonNumber == n }
    }
}

// MARK: - Season chips + drill box

/// Two-column season chips; one bar row per edition.
struct SeasonChipGrid: View {
    let detail: ItemDetail
    let editions: [DetailEdition]
    @Binding var selected: Int?
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dim)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                ForEach((detail.seasons ?? []).sorted { $0.seasonNumber < $1.seasonNumber }) { season in
                    chip(season)
                }
            }
        }
    }

    private func chip(_ season: Season) -> some View {
        let isSelected = selected == season.seasonNumber
        let unmonitored = season.monitored == false
        let covers = editions.map { season.cover(editionId: $0.id) }
        let combined = covers.reduce(Cover(), +)
        let allDone = !covers.isEmpty && covers.allSatisfy { $0.state == .done }
        let state: Cover.State = allDone ? .done : combined.state
        return Button {
            selected = season.seasonNumber
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("S\(season.seasonNumber)").font(.system(size: 11, weight: .heavy)).foregroundStyle(Theme.txt)
                    Spacer()
                    mark(state, unmonitored: unmonitored)
                }
                ForEach(editions.indices, id: \.self) { i in
                    let edition = editions[i], cover = covers[i]
                    HStack(spacing: 6) {
                        Text(edition.tier.tierShort)
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(DetailTokens.tier(edition.tier))
                            .frame(width: 16, alignment: .leading)
                        DetailCoverageBar(total: cover.total, owned: cover.owned, grabbing: cover.grabbing,
                                    color: cover.state == .done && edition.tier == .hd ? Theme.done : DetailTokens.tier(edition.tier),
                                    height: 4)
                        Text("\(cover.owned)/\(cover.total)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Theme.mut)
                    }
                }
            }
            .opacity(unmonitored ? 0.6 : 1)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(unmonitored ? Color.clear : Theme.panel, in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                if unmonitored {
                    RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                } else {
                    RoundedRectangle(cornerRadius: 9).strokeBorder(isSelected ? Theme.cyan.mix(0.5, Theme.panel) : Theme.line,
                                                                     lineWidth: isSelected ? 2 : 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(DetailPressStyle())
        .detailAnimation(.easeInOut(duration: 0.14), value: isSelected)
        .accessibilityLabel("Season \(season.seasonNumber)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func mark(_ state: Cover.State, unmonitored: Bool) -> some View {
        if unmonitored {
            Text("⊘").foregroundStyle(Theme.mut)
        } else {
            switch state {
            case .done: Text("✓").foregroundStyle(Theme.done)
            case .part: Text("◐").foregroundStyle(Theme.grab)
            case .empty: Text("○").foregroundStyle(Theme.miss)
            }
        }
    }
}

/// The selected season's drill box: one tick row per edition.
struct DrillBox: View {
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    let season: Season
    let editions: [DetailEdition]

    private var canSearch: Bool { model.me?.can("search") ?? true }

    var body: some View {
        let covers = editions.map { season.cover(editionId: $0.id) }
        let combined = covers.reduce(Cover(), +)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(season.title).font(.system(size: 12.5, weight: .bold)).foregroundStyle(Theme.txt)
                Text("\(combined.owned)/\(combined.total)\(combined.grabbing > 0 ? " · grabbing \(combined.grabbing)" : "")")
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(Theme.mut)
                Spacer(minLength: 0)
                if editions.count == 1, let edition = editions.first, canSearch {
                    SearchActionButton(label: "\(season.title) · \(edition.tier.chipLabel)", editionId: edition.id,
                                       season: season.seasonNumber, size: 28, glyph: 14)
                }
            }
            ForEach(editions) { edition in
                HStack(alignment: .top, spacing: 6) {
                    Text(edition.versionKey.isEmpty ? edition.tier.chipLabel : edition.label)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(DetailTokens.tier(edition.tier))
                        .lineLimit(2)
                        .frame(width: 56, alignment: .leading)
                        .padding(.top, 1)
                    FlowRow(spacing: 4) {
                        ForEach(season.episodes.sorted { $0.episodeNumber < $1.episodeNumber }) { episode in
                            EpisodeTick(season: season, episode: episode, edition: edition)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if editions.count > 1, canSearch {
                        SearchActionButton(label: "\(season.title) · \(edition.label)", editionId: edition.id,
                                           season: season.seasonNumber, size: 28, glyph: 14)
                    }
                }
            }
            Text(editions.count > 1
                 ? "Aligned by episode — a gap in one row is a missing edition. Tap a tick for the episode + which edition."
                 : "Tap a tick for its episode number + status. Tap another season to switch.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.dim)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line))
        .padding(.top, 2)
        .id(season.seasonNumber)
        .transition(.opacity)
    }
}

/// One episode tick; tapping it shows the code, status + quality and title.
private struct EpisodeTick: View {
    let season: Season
    let episode: Episode
    let edition: DetailEdition
    @State private var showing = false

    var body: some View {
        let kind = episode.status(editionId: edition.id)
        let tier = DetailTokens.tier(edition.tier)
        Button { showing = true } label: {
            tickShape(kind, tier: tier)
                .frame(width: 18, height: 12)
                .contentShape(Rectangle())
                .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showing) {
            VStack(alignment: .leading, spacing: 4) {
                Text("S\(season.seasonNumber)·E\(String(format: "%02d", episode.episodeNumber))")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.txt)
                Text(kind.statusText + (episode.file(for: edition.id).map { " · " + DetailText.quality($0.quality) } ?? ""))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(kind.tick == .owned ? tier : (kind.tick == .grab ? Theme.grab : Theme.mut))
                if let title = episode.title {
                    Text(title).font(.system(size: 12)).foregroundStyle(Theme.mut)
                }
            }
            .padding(12)
            .presentationCompactAdaptation(.popover)
            .presentationBackground(Theme.panel2)
        }
        .accessibilityLabel("S\(season.seasonNumber) E\(episode.episodeNumber), \(kind.statusText)")
    }

    @ViewBuilder
    private func tickShape(_ kind: EpisodeStatusKind, tier: Color) -> some View {
        let shape = RoundedRectangle(cornerRadius: 2)
        switch kind.tick {
        case .owned:
            shape.fill(tier)
        case .grab:
            shape.fill(Theme.grab).detailPulse()
        case .want:
            if kind == .soon {
                shape.fill(Theme.dim.opacity(0.35))
            } else {
                shape.strokeBorder(Theme.miss.mix(0.45, Theme.panel))
            }
        }
    }
}

// MARK: - D.8 versions × tiers matrix

struct MatrixReveal: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RevealHeader(label: "All editions · versions × tiers", detail: detail, railEdition: nil) { DetailDualDots() }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(detail.versionKeys, id: \.self) { version in
                    Text(versionLabel(version))
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Theme.anime)
                        .padding(.top, 4)
                    ForEach(detail.distinctTiers, id: \.self) { tier in
                        if let edition = detail.editions.first(where: { $0.tier == tier && $0.versionKey == version }) {
                            cell(edition)
                        } else {
                            emptyCell(tier: tier, version: version)
                        }
                    }
                }
            }
            .padding(.horizontal, 15)
            .padding(.bottom, 15)
        }
    }

    private func cell(_ edition: DetailEdition) -> some View {
        let cover = detail.cover(edition: edition)
        let tierColor = DetailTokens.tier(edition.tier)
        let state = seriesState(cover, upgrading: edition.downloadState == "upgrading")
        let washColor: Color? = {
            switch state {
            case .ok: return nil
            case .part: return Theme.grab
            case .want: return Theme.miss
            case .soon: return Theme.unaired
            case .upgrading: return Theme.edition
            }
        }()
        return Button {
            store.scope = DetailScope(tier: edition.tier.rawValue, version: edition.versionKey)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                FlowRow(spacing: 8, lineSpacing: 6) {
                    HStack(spacing: 8) {
                        DetailDot(color: tierColor, size: 9)
                        Text(edition.tier.chipLabel).font(.system(size: 15, weight: .heavy)).foregroundStyle(tierColor)
                    }
                    if !edition.versionKey.isEmpty { DetailVersionTag(text: edition.versionKey) }
                    DetailStatePill(kind: state)
                }
                (Text("\(cover.owned)").font(.system(size: 16, weight: .heavy, design: .monospaced)).foregroundColor(Theme.txt)
                    + Text(" / \(cover.total) episodes").font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(Theme.mut))
                DetailCoverageBar(total: cover.total, owned: cover.owned, grabbing: cover.grabbing, color: tierColor, height: 6)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if let washColor {
                    LinearGradient(stops: [
                        .init(color: washColor.mix(0.13, Theme.panel), location: 0),
                        .init(color: Theme.panel, location: 0.42),
                    ], startPoint: .leading, endPoint: .trailing)
                } else {
                    Theme.panel
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line))
            .contentShape(Rectangle())
        }
        .buttonStyle(DetailPressStyle())
        .accessibilityLabel("\(edition.label), \(cover.owned) of \(cover.total) episodes")
    }

    private func emptyCell(tier: QualityTier, version: String) -> some View {
        VStack(alignment: .leading) {
            if model.me?.can("edit") ?? true {
                Button {
                    store.addPreset = AddEditionPreset(tier: tier, version: version)
                } label: {
                    Text("+ add \(versionLabel(version)) · \(tier.chipLabel)")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Theme.mut)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            } else {
                Text("\(versionLabel(version)) · \(tier.chipLabel) not tracked")
                    .font(.system(size: 11.5)).foregroundStyle(Theme.dim)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
    }
}
