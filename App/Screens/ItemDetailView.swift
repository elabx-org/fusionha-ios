import SwiftUI
import FusionhaKit

enum DetailTab: Hashable {
    case seasons, history
}

/// The web's item detail sheet on mobile: sticky title bar with close, hero,
/// status pill, title + year, meta, genres, overview, item actions, the
/// per-edition cards and the Seasons / History tabs.
struct ItemDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let itemId: Int
    @State private var detail: ItemDetail?
    @State private var profiles: [Int: String] = [:]
    @State private var error: String?
    @State private var tab: DetailTab = .seasons
    @State private var searchSent = false
    @State private var searching = false

    /// The library row carries the per-edition have/total and status.
    private var summary: MediaItem? { model.library.first { $0.id == itemId } }

    var body: some View {
        ScrollView {
            if let detail {
                content(detail)
            } else if error != nil {
                EmptyBox(message: "This title could not be loaded.").padding(16).padding(.top, 60)
            } else {
                ProgressView().tint(Theme.mut).frame(maxWidth: .infinity).padding(.top, 120)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { titleBar }
        .background(Theme.bg)
        .task { await load() }
    }

    private var titleBar: some View {
        HStack {
            Text(detail?.title ?? summary?.title ?? "")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.txt)
                .lineLimit(1)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                    .frame(width: 38, height: 38)
                    .panel(Theme.panel, radius: 10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 12)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(Theme.bg)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    @ViewBuilder
    private func content(_ d: ItemDetail) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PosterImage(url: TMDBImage.resized(d.backdropUrl ?? d.posterUrl, to: "w1280"))
                .frame(height: 230)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(LinearGradient(colors: [.clear, Theme.bg], startPoint: .center, endPoint: .bottom))

            VStack(alignment: .leading, spacing: 16) {
                if let status = d.status {
                    StatusPill(text: status)
                }
                (Text(d.title).foregroundColor(Theme.txt)
                    + Text(d.year.map { " \($0)" } ?? "").foregroundColor(Theme.mut))
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-0.6)
                metaLine(d)
                if let genres = d.genres, !genres.isEmpty {
                    FlowRow(spacing: 8) {
                        ForEach(genres, id: \.self) { genre in
                            Text(genre)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.txt)
                                .padding(.horizontal, 12)
                                .frame(height: 30)
                                .overlay(Capsule().strokeBorder(Theme.line))
                        }
                    }
                }
                if let overview = d.overview {
                    Text(overview).font(.system(size: 16)).foregroundStyle(Theme.txt.opacity(0.9)).lineSpacing(3)
                }
                actions(d)
                EyebrowLabel(text: "Quality editions")
                    .padding(.top, 6)
                ForEach(d.editions) { edition in
                    EditionPanel(item: d, edition: edition,
                                 summary: summary?.editions.first { $0.id == edition.id },
                                 profileName: edition.qualityProfileId.flatMap { profiles[$0] })
                }
                if d.kind == .series || !(d.history ?? []).isEmpty {
                    SegmentedPills(options: d.kind == .series
                                   ? [(DetailTab.seasons, "Seasons"), (.history, "History")]
                                   : [(DetailTab.history, "History")],
                                   selection: $tab, style: .plain)
                        .padding(.top, 8)
                    if tab == .seasons && d.kind == .series {
                        ForEach((d.seasons ?? []).sorted { $0.seasonNumber > $1.seasonNumber }) { season in
                            SeasonPanel(season: season, editions: d.editions)
                        }
                    } else {
                        ForEach(d.history ?? []) { HistoryRow(entry: $0) }
                        if (d.history ?? []).isEmpty {
                            EmptyBox(message: "No history for this title yet.")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, -24)
            .padding(.bottom, 40)
        }
        .onAppear { if d.kind == .movie { tab = .history } }
    }

    private func metaLine(_ d: ItemDetail) -> some View {
        var parts: [Text] = []
        parts.append(Text(d.isAnime == true ? "Anime" : (d.kind == .movie ? "Movie" : "Series")))
        parts.append(Text("\(d.editions.count) edition\(d.editions.count == 1 ? "" : "s")"))
        if let runtime = d.runtime, runtime > 0 { parts.append(Text("\(runtime) min")) }
        if let vote = d.voteAverage, vote > 0 {
            parts.append(Text(Image(systemName: "star")).foregroundColor(Theme.onair) + Text(String(format: " %.1f", vote)))
        }
        if let cert = d.certification { parts.append(Text(cert).font(.system(size: 13, weight: .bold, design: .monospaced))) }
        var line = Text("")
        for (index, part) in parts.enumerated() {
            line = index == 0 ? part : line + Text("  ·  ").foregroundColor(Theme.dim) + part
        }
        return line.font(.system(size: 15)).foregroundStyle(Theme.mut)
    }

    private func actions(_ d: ItemDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: "Item actions")
            HStack(spacing: 0) {
                actionButton(searchSent ? "checkmark" : "magnifyingglass", "Automatic search") {
                    Task {
                        searching = true
                        try? await model.client?.searchItem(id: d.id)
                        searching = false
                        searchSent = true
                    }
                }
                .disabled(searching)
                actionButton("arrow.clockwise", "Reload") { Task { await load() } }
                if let server = model.credentials?.serverURL {
                    actionButton("safari", "Open in web app") {
                        openURL(server.appendingPathComponent("library/\(d.id)"))
                    }
                }
            }
            .padding(.vertical, 6)
            .panel(Theme.panel, radius: 14)
            Text("acts on ").foregroundColor(Theme.dim)
                + Text("all editions").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(Theme.txt)
        }
        .font(.system(size: 13))
        .sensoryFeedback(.success, trigger: searchSent)
    }

    private func actionButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(symbol == "checkmark" ? Theme.done : Theme.txt)
                .contentTransition(.symbolEffect(.replace))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            detail = try await client.item(id: itemId)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        if profiles.isEmpty, let list = try? await client.qualityProfiles() {
            profiles = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0.name) })
        }
    }
}

/// The green/blue status capsule (`RELEASED`, `ENDED`, `CONTINUING`…).
private struct StatusPill: View {
    let text: String

    private var color: Color {
        switch text.lowercased() {
        case "released", "ended": return Theme.done
        case "continuing", "returning series", "in production": return Theme.onair
        default: return Theme.unaired
        }
    }

    var body: some View {
        Label(text.uppercased(), systemImage: "clock")
            .font(.system(size: 12, weight: .heavy, design: .monospaced))
            .tracking(1)
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(color.opacity(0.14), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.5)))
    }
}

/// One quality edition: header with counts, coverage bar, legend, info grid.
private struct EditionPanel: View {
    let item: ItemDetail
    let edition: DetailEdition
    let summary: Edition?
    let profileName: String?

    var body: some View {
        let rail = summary?.rail(isSeries: item.kind == .series)
        let color = rail?.state.color ?? Theme.unmonitored
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Circle().fill(color).frame(width: 9, height: 9)
                    Text(edition.tier.chipLabel)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.txt)
                    if let fraction = rail?.fraction {
                        Text(fraction).font(.system(size: 14).monospacedDigit()).foregroundStyle(Theme.mut)
                    }
                    if let cut = edition.movieEdition {
                        Text(cut)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.edition)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Theme.edition.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                    }
                    Spacer(minLength: 0)
                    if let state = rail?.state {
                        Text(state.label)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(color)
                            .padding(.horizontal, 9).padding(.vertical, 3)
                            .background(color.opacity(0.12), in: Capsule())
                            .overlay(Capsule().strokeBorder(color.opacity(0.5)))
                    }
                }
                if let rail {
                    RailBar(progress: rail.progress, color: color, state: rail.state)
                }
            }
            .padding(16)

            Rectangle().fill(Theme.line).frame(height: 1)
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    cell("Root folder", rootFolder)
                    cell("Quality profile", profileName ?? "—")
                }
                Divider().overlay(Theme.line)
                GridRow {
                    cell("Monitoring", edition.monitored ? "Monitored" : "Unmonitored",
                         color: edition.monitored ? Theme.cyan : Theme.mut)
                    cell("Size", Format.bytes(summary?.size))
                }
            }
            if let file = edition.movieFile {
                Rectangle().fill(Theme.line).frame(height: 1)
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.relativePath ?? "")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.mut)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        if let q = file.quality {
                            Text(q.replacingOccurrences(of: "_", with: "-"))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(edition.tier.color)
                        }
                        if let group = file.releaseGroup { Text(group).font(.system(size: 11)).foregroundStyle(Theme.mut) }
                        Text(Format.bytes(file.size)).font(.system(size: 11)).foregroundStyle(Theme.mut)
                    }
                }
                .padding(16)
            }
        }
        .panel(Theme.card, radius: 16)
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16)
                .fill(color).frame(height: 2).padding(.horizontal, 1)
        }
    }

    private var rootFolder: String {
        guard let path = edition.fullPath else { return "—" }
        return (path as NSString).deletingLastPathComponent
    }

    private func cell(_ label: String, _ value: String, color: Color = Theme.txt) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            EyebrowLabel(text: label)
            Text(value)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }
}

extension RailState {
    var label: String {
        switch self {
        case .owned: return "Downloaded"
        case .partial: return "Partial"
        case .wanted: return "Missing"
        case .downloading: return "Downloading"
        case .upgrading: return "Upgrading"
        case .upcoming: return "Upcoming"
        }
    }
}

/// A season with its episode rows (number, title, air date, status).
private struct SeasonPanel: View {
    let season: Season
    let editions: [DetailEdition]
    @State private var expanded: Bool

    init(season: Season, editions: [DetailEdition]) {
        self.season = season
        self.editions = editions
        _expanded = State(initialValue: false)
    }

    private var have: Int { season.episodes.filter { !($0.files ?? []).isEmpty }.count }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.snappy) { expanded.toggle() }
            } label: {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                            .foregroundStyle(Theme.mut)
                        Text(season.seasonNumber == 0 ? "Specials" : "Season \(season.seasonNumber)")
                            .font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
                        Text("\(have)/\(season.episodes.count)").font(.system(size: 14).monospacedDigit()).foregroundStyle(Theme.mut)
                        Spacer()
                        Image(systemName: season.monitored == false ? "bookmark" : "bookmark.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(season.monitored == false ? Theme.mut : Theme.cyan)
                    }
                    RailBar(progress: season.episodes.isEmpty ? 0 : have * 100 / season.episodes.count,
                            color: have == season.episodes.count ? Theme.done : Theme.miss,
                            state: have == season.episodes.count ? .owned : .partial)
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                ForEach(season.episodes.sorted { $0.episodeNumber > $1.episodeNumber }) { episode in
                    Rectangle().fill(Theme.line).frame(height: 1)
                    EpisodeRow(episode: episode)
                }
            }
        }
        .panel(Theme.card, radius: 14)
    }
}

private struct EpisodeRow: View {
    let episode: Episode

    private var state: (String, Color) {
        if let dl = episode.downloadStates?.first {
            let pct = dl.progress.map { " \(Int($0))%" } ?? ""
            return ((dl.state ?? "downloading").uppercased() + pct, Theme.grab)
        }
        if let file = episode.files?.first?.file {
            return ((file.quality ?? "Downloaded").replacingOccurrences(of: "_", with: "-"), Theme.edition)
        }
        if let air = Format.day(episode.airDate), air > .now { return ("unaired", Theme.unaired) }
        if episode.monitored == false { return ("unmonitored", Theme.unmonitored) }
        return ("missing", Theme.danger)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(state.1).frame(width: 7, height: 7).padding(.top, 6)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(episode.episodeNumber)").font(.system(size: 14, weight: .bold).monospacedDigit()).foregroundStyle(Theme.txt)
                Text(Format.day(episode.airDate)?.formatted(.dateTime.month(.abbreviated).day()) ?? "TBA")
                    .font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
            .frame(width: 52, alignment: .leading)
            VStack(alignment: .trailing, spacing: 6) {
                Text(episode.title ?? "TBA")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(state.0)
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(state.1)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(state.1.opacity(0.55)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

/// Wrapping row for chips (genres).
struct FlowRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
