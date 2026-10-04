import SwiftUI
import FusionhaKit

extension EnvironmentValues {
    /// Press-and-hold on a Library poster opens its quick-actions sheet.
    @Entry var openPosterSheet: ((MediaItem) -> Void)?
}

// MARK: - Interactive search scoping (components/library/poster-sheet-model.ts)

/// What an interactive search from the poster sheet will cover.
enum SheetSearchTarget: Hashable {
    case item
    case season(Int)
    case episode(season: Int, id: Int, number: Int)
}

struct SheetVersionOption: Identifiable {
    let id: Int
    let label: String
    /// No file for the target yet.
    let missing: Bool
}

enum PosterSheetModel {
    private static func hasFile(_ episode: Episode, _ versionId: Int) -> Bool {
        (episode.files ?? []).contains { $0.editionId == versionId && $0.file != nil }
    }

    private static func episodes(_ data: ItemDetail, _ target: SheetSearchTarget) -> [Episode] {
        let seasons = data.seasons ?? []
        switch target {
        case .episode(let season, let id, _):
            return seasons.first { $0.seasonNumber == season }?.episodes.filter { $0.id == id } ?? []
        case .season(let season):
            return seasons.first { $0.seasonNumber == season }?.episodes ?? []
        case .item:
            // Whole series: regular seasons only — specials never drive the pick.
            return seasons.filter { $0.seasonNumber > 0 }.flatMap(\.episodes)
        }
    }

    static func isSeries(_ data: ItemDetail) -> Bool { !(data.seasons ?? []).isEmpty }

    /// Every version, in the item's own order, flagged missing for `target`.
    static func versionOptions(_ data: ItemDetail, _ target: SheetSearchTarget, now: Date) -> [SheetVersionOption] {
        let series = isSeries(data)
        let eps = series ? episodes(data, target) : []
        // The whole series only counts aired episodes, so a far-future season
        // never marks an otherwise complete version missing.
        let relevant: [Episode]
        if case .item = target { relevant = eps.filter { $0.hasAired(now: now) } } else { relevant = eps }
        return data.editions.map { ed in
            let missing = series ? relevant.contains { !hasFile($0, ed.id) } : ed.movieFile == nil
            return SheetVersionOption(id: ed.id, label: ed.label, missing: missing)
        }
    }

    /// The likely pick: the first missing version, else the last (usually 4K).
    static func recommended(_ options: [SheetVersionOption]) -> Int? {
        (options.first { $0.missing } ?? options.last)?.id
    }

    struct SeasonSummary: Identifiable {
        let number: Int
        let label: String
        let total: Int
        let aired: Int
        let missing: Int
        var id: Int { number }
    }

    private static func wantedIds(_ data: ItemDetail) -> [Int] {
        let monitored = data.editions.filter(\.monitored).map(\.id)
        return monitored.isEmpty ? data.editions.map(\.id) : monitored
    }

    /// Seasons newest first, Specials last.
    static func seasonSummaries(_ data: ItemDetail, now: Date) -> [SeasonSummary] {
        let seasons = data.seasons ?? []
        let ordered = seasons.filter { $0.seasonNumber > 0 }.sorted { $0.seasonNumber > $1.seasonNumber }
            + seasons.filter { $0.seasonNumber == 0 }
        let wanted = wantedIds(data)
        return ordered.map { season in
            let aired = season.episodes.filter { $0.hasAired(now: now) }
            return SeasonSummary(number: season.seasonNumber,
                                 label: season.seasonNumber == 0 ? "Specials" : "Season \(season.seasonNumber)",
                                 total: season.episodes.count, aired: aired.count,
                                 missing: aired.filter { ep in wanted.contains { !hasFile(ep, $0) } }.count)
        }
    }

    enum EpisodeState { case have, missing, partial, unaired }

    struct EpisodeRow: Identifiable {
        let id: Int
        let number: Int
        let title: String
        let state: EpisodeState
        let missingLabels: [String]
    }

    static func episodeRows(_ data: ItemDetail, season number: Int, now: Date) -> [EpisodeRow] {
        guard let season = (data.seasons ?? []).first(where: { $0.seasonNumber == number }) else { return [] }
        let ids = wantedIds(data)
        let wanted = data.editions.filter { ids.contains($0.id) }
        return season.episodes.sorted { $0.episodeNumber < $1.episodeNumber }.map { ep in
            let lacking = wanted.filter { !hasFile(ep, $0.id) }
            let state: EpisodeState
            if lacking.isEmpty { state = .have }
            else if !ep.hasAired(now: now) { state = .unaired }
            else { state = lacking.count == wanted.count ? .missing : .partial }
            return EpisodeRow(id: ep.id, number: ep.episodeNumber, title: ep.title ?? "Episode \(ep.episodeNumber)",
                              state: state, missingLabels: state == .partial ? lacking.map(\.label) : [])
        }
    }

    /// The heading subtitle the search sheet shows for a target.
    static func subtitle(_ target: SheetSearchTarget, version: DetailEdition) -> String {
        switch target {
        case .episode(let season, _, let number): return "S\(season)·E\(number)"
        case .season(let season): return "S\(season) · Season pack"
        case .item: return version.label
        }
    }
}

// MARK: - Sheet (LibraryPosterSheet.tsx + ui/ActionSheet.tsx)

/// The Library poster's press-and-hold sheet. Same actions as the old ⋯ menu —
/// Automatic search, Interactive search, Monitor, Refresh, Edit, Delete — but
/// Interactive search drills in: a series picks a season (or the whole series),
/// then the whole season or one episode, then the version; a movie picks the
/// version. A single-version title opens the search straight away.
struct LibraryPosterSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.motionEnabled) private var motion
    let item: MediaItem

    private indirect enum Page: Hashable {
        case actions, seasons
        case episodes(Int)
        case versions(SheetSearchTarget, back: Page)
    }

    @State private var page: Page = .actions
    @State private var detail: ItemDetail?
    @State private var loadFailed = false
    /// Set only when THIS open parked a single-version target waiting for the detail.
    @State private var pendingLaunch = false
    @State private var contentHeight: CGFloat = 360

    private var monitored: Bool { item.monitored ?? true }
    private var isSeries: Bool { item.kind != .movie }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.trailing, 30)
                .padding(.bottom, 14)
            ScrollView {
                pageBody
                    .id(page)
                    .transition(motion && page != .actions
                                ? .asymmetric(insertion: .opacity.combined(with: .offset(x: 18)), removal: .identity)
                                : .identity)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.mut)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .padding(.top, 10)
            .padding(.trailing, 12)
            .accessibilityLabel("Close")
        }
        .presentationDetents([.height(min(contentHeight + 116, 640)), .large])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.selection, trigger: page)
        .task(id: item.id) {
            await load()
            #if DEBUG
            // CI screenshots: `FUSIONHA_SCREENSHOT_POSTER_PAGE=seasons|versions` opens that drill page.
            switch ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_POSTER_PAGE"] {
            case "seasons": page = .seasons
            case "versions": page = .versions(.item, back: .actions)
            default: break
            }
            #endif
        }
        .accessibilityLabel("Actions for \(item.title)")
    }

    private func load() async {
        guard detail == nil, let client = model.client else { return }
        do {
            let loaded = try await client.item(id: item.id)
            detail = loaded
            if pendingLaunch, case .versions(let target, _) = page, loaded.editions.count == 1 {
                pendingLaunch = false
                launch(loaded, target, versionId: loaded.editions[0].id)
            }
        } catch {
            loadFailed = true
        }
    }

    private func go(_ next: Page) {
        withAnimation(motion ? .timingCurve(0.2, 0.9, 0.25, 1, duration: 0.26) : nil) { page = next }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            PosterImage(url: TMDBImage.resized(item.posterUrl, to: "w154"))
                .aspectRatio(2 / 3, contentMode: .fill)
                .frame(width: 44, height: 66)
                .background(Theme.panel2)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Theme.line))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                let rails = item.rails
                FlowChips(spacing: 5) {
                    if let year = item.year { chip(String(year)) }
                    ForEach(item.editions.indices, id: \.self) { index in
                        versionChip(item.editions[index], rail: rails[index])
                    }
                    if !monitored { chip("Unmonitored") }
                }
            }
        }
    }

    private func versionChip(_ edition: Edition, rail: Rail) -> some View {
        var text = ""
        if let cut = edition.movieEdition, !cut.isEmpty { text += "\(cut) · " }
        text += edition.tier == .hd ? "HD" : "4K"
        if isSeries, let total = edition.total, total > 0 { text += " \(edition.have ?? 0)/\(total)" }
        let color: Color?
        switch rail.state {
        case .owned: color = Theme.done
        case .downloading, .upgrading: color = Theme.i2
        case .wanted: color = Theme.miss
        default: color = nil
        }
        return chip(text, color: color)
    }

    private func chip(_ text: String, color: Color? = nil) -> some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(color ?? Theme.mut)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 1)
            .background(color.map { $0.opacity(0.13) } ?? Theme.panel2, in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: Pages

    @ViewBuilder
    private var pageBody: some View {
        switch page {
        case .actions: actionsPage
        case .seasons: seasonsPage
        case .episodes(let season): episodesPage(season)
        case .versions(let target, let back): versionsPage(target, back: back)
        }
    }

    private func run(_ action: @escaping () -> Void) -> () -> Void {
        { dismiss(); action() }
    }

    private var actionsPage: some View {
        SheetList {
            SheetRow(index: 0, label: "Automatic search", icon: "magnifyingglass", tone: .primary,
                     action: run { model.autoSearch(item.id) })
            SheetRow(index: 1, label: "Interactive search", icon: "person",
                     chevron: isSeries || item.editions.count > 1, action: startInteractive)
            SheetRow(index: 2, label: monitored ? "Unmonitor" : "Monitor",
                     icon: monitored ? "bookmark.fill" : "bookmark",
                     action: run { model.setMonitored(item.id, title: item.title, monitored: !monitored) })
            SheetSeparator()
            SheetRow(index: 3, label: "Refresh metadata", icon: "arrow.clockwise",
                     action: run { model.refreshMetadata(item.id, title: item.title) })
            SheetRow(index: 4, label: "Edit…", icon: "pencil", action: run { model.edit(item.id) })
            SheetRow(index: 5, label: "Delete…", icon: "trash", tone: .danger,
                     action: run { model.confirmDelete(item.id, title: item.title) })
        }
    }

    private func startInteractive() {
        if isSeries { go(.seasons) } else { choose(.item, back: .actions) }
    }

    /// One version → search now; several → pick the version.
    private func choose(_ target: SheetSearchTarget, back: Page) {
        if let detail, detail.editions.count == 1 {
            launch(detail, target, versionId: detail.editions[0].id)
            return
        }
        pendingLaunch = detail == nil
        go(.versions(target, back: back))
    }

    private func launch(_ data: ItemDetail, _ target: SheetSearchTarget, versionId: Int, all: Bool = false) {
        guard let version = data.editions.first(where: { $0.id == versionId }) else { return }
        var ids = [versionId]
        if all { ids += data.editions.map(\.id).filter { $0 != versionId } }
        var episodeId: Int?, seasonNumber: Int?
        switch target {
        case .episode(_, let id, _): episodeId = id
        case .season(let season): seasonNumber = season
        case .item: break
        }
        let subtitle = all && target == .item ? "All versions" : PosterSheetModel.subtitle(target, version: version)
        dismiss()
        model.scopedSearch(item.id, ScopedSearch(editionIds: ids, episodeId: episodeId,
                                                 seasonNumber: seasonNumber, subtitle: subtitle))
    }

    @ViewBuilder
    private var waiting: some View {
        Text(loadFailed ? "Couldn't load this title. Try again." : "Loading…")
            .font(.system(size: 13.5))
            .foregroundStyle(Theme.mut)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
    }

    private var seasonsPage: some View {
        SheetPage(title: "Interactive search", caption: "What do you want to search for?") { go(.actions) } content: {
            if let detail {
                let seasons = PosterSheetModel.seasonSummaries(detail, now: Date())
                let latest = seasons.first { $0.number > 0 }?.number
                SheetList {
                    ForEach(Array(seasons.enumerated()), id: \.element.id) { i, s in
                        let state = s.missing > 0 ? "\(s.missing) missing" : (s.aired == 0 ? "not aired yet" : "complete")
                        SheetRow(index: i, label: s.label, detail: "\(state) · \(s.aired)/\(s.total) aired",
                                 tone: s.number == latest ? .recommended : .normal, chevron: true) {
                            go(.episodes(s.number))
                        }
                    }
                    SheetSeparator()
                    SheetRow(index: seasons.count, label: "Whole series", detail: "complete-series packs", chevron: true) {
                        choose(.item, back: .seasons)
                    }
                }
            } else {
                waiting
            }
        }
    }

    private func episodesPage(_ season: Int) -> some View {
        let label = season == 0 ? "Specials" : "Season \(season)"
        return SheetPage(title: label) { go(.seasons) } content: {
            if let detail {
                SheetList {
                    SheetRow(index: 0, label: "Whole season", detail: "season packs + every episode in \(label)",
                             tone: .recommended, chevron: true) {
                        choose(.season(season), back: .episodes(season))
                    }
                }
                SheetGroupLabel(text: "Or one episode")
                SheetList {
                    let rows = PosterSheetModel.episodeRows(detail, season: season, now: Date())
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, r in
                        SheetRow(index: i + 1, label: String(format: "%02d · %@", r.number, r.title),
                                 detail: episodeDetail(r),
                                 tone: r.state == .missing || r.state == .partial ? .recommended : .normal,
                                 chevron: true) {
                            choose(.episode(season: season, id: r.id, number: r.number), back: .episodes(season))
                        }
                    }
                }
            } else {
                waiting
            }
        }
    }

    private func episodeDetail(_ row: PosterSheetModel.EpisodeRow) -> String {
        switch row.state {
        case .have: return "has a file"
        case .missing: return "missing"
        case .partial: return "\(row.missingLabels.joined(separator: ", ")) missing"
        case .unaired: return "not aired yet"
        }
    }

    private func versionsPage(_ target: SheetSearchTarget, back: Page) -> some View {
        let what: String
        switch target {
        case .episode(let season, _, let number): what = "S\(season)·E\(number)"
        case .season(let season): what = "Season \(season) · season pack"
        case .item: what = isSeries ? "Whole series" : item.title
        }
        return SheetPage(title: "Which version?", caption: what) {
            pendingLaunch = false
            go(back)
        } content: {
            if let detail {
                let options = PosterSheetModel.versionOptions(detail, target, now: Date())
                let rec = PosterSheetModel.recommended(options)
                SheetList {
                    ForEach(Array(options.enumerated()), id: \.element.id) { i, o in
                        SheetRow(index: i, label: o.label,
                                 detail: o.id == rec && o.missing ? "missing — most likely what you want"
                                     : (o.missing ? "missing" : "has a file · look for an upgrade"),
                                 tone: o.id == rec ? .recommended : .normal, hint: "1 query") {
                            launch(detail, target, versionId: o.id)
                        }
                    }
                    if options.count > 1 {
                        SheetSeparator()
                        SheetRow(index: options.count, label: "All versions", detail: "switch between them in the results",
                                 hint: "\(options.count) queries") {
                            launch(detail, target, versionId: rec ?? options[0].id, all: true)
                        }
                    }
                }
            } else {
                waiting
            }
        }
    }
}

// MARK: - Action sheet parts (ui/ActionSheet.module.css)

private struct SheetList<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(.horizontal, -8)
            .padding(.top, 2)
            .padding(.bottom, 4)
    }
}

private struct SheetSeparator: View {
    var body: some View {
        Rectangle().fill(Theme.line).frame(height: 1)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
    }
}

private struct SheetGroupLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11))
            .tracking(0.88)
            .foregroundStyle(Theme.mut)
            .padding(.top, 10)
            .padding(.bottom, 2)
    }
}

/// A drilled page: `‹ Back` + title, an optional caption, then its rows.
private struct SheetPage<Content: View>: View {
    let title: String
    var caption: String?
    let back: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Button(action: back) {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                        Text("Back").font(.system(size: 15))
                    }
                    .foregroundStyle(Theme.i2)
                    .padding(.leading, 4)
                    .padding(.trailing, 10)
                    .frame(minHeight: 40)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                    .lineLimit(1)
            }
            .padding(.horizontal, -8)
            .padding(.top, -4)
            .padding(.bottom, 2)
            if let caption {
                Text(caption)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.mut)
                    .padding(.bottom, 4)
            }
            content
        }
    }
}

private struct SheetRow: View {
    enum Tone { case normal, primary, danger, recommended }

    @Environment(\.motionEnabled) private var motion
    let index: Int
    let label: String
    var detail: String?
    var icon: String?
    var tone: Tone = .normal
    var hint: String?
    var chevron = false
    let action: () -> Void
    @State private var shown = false

    private var color: Color {
        switch tone {
        case .primary: return Theme.i2
        case .danger: return Theme.danger
        default: return Theme.txt
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .regular))
                        .frame(width: 26)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(label).font(.system(size: 16))
                    if let detail {
                        Text(detail)
                            .font(.system(size: 12.5))
                            .foregroundStyle(tone == .recommended ? Theme.miss : Theme.mut)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let hint {
                    Text(hint)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(Theme.mut)
                        .lineLimit(1)
                }
                if chevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.mut)
                }
            }
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(SheetRowStyle())
        // Rows rise in with a short stagger (off under Reduce Motion).
        .opacity(shown || !motion ? 1 : 0)
        .offset(y: shown || !motion ? 0 : 6)
        .onAppear {
            guard motion, !shown else { return }
            withAnimation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.24).delay(Double(min(index, 10)) * 0.018 + 0.04)) {
                shown = true
            }
        }
    }
}

private struct SheetRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Theme.txt.opacity(configuration.isPressed ? 0.07 : 0),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Wrapping chip row (`flex-wrap`).
private struct FlowChips<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        FlowLayout(spacing: spacing) { content }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += line + spacing; line = 0 }
            x += size.width + spacing
            line = max(line, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, width), height: y + line)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, line: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX { x = bounds.minX; y += line + spacing; line = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            line = max(line, size.height)
        }
    }
}
