import SwiftUI
import FusionhaKit

// MARK: - Sheet (LibraryPosterSheet.tsx + ui/ActionSheet.tsx)
//
// The scoping model (PosterSheetModel), the drill pages
// (LibraryPosterSheet+Pages) and the row parts (PosterSheetParts) live in
// App/Screens/Detail/.

/// The Library poster's press-and-hold sheet (redesign `poster-sheet`). Same
/// actions as the old ⋯ menu: Automatic search (the cream primary),
/// Interactive search, Monitor (a switch), Refresh, Edit, Delete. Interactive
/// search drills in: a series picks a season (or the whole series), then the
/// whole season or one episode, then the version; a movie picks the version.
/// A single-version title opens the search straight away.
struct LibraryPosterSheet: View {
    @Environment(AppModel.self) var model
    @Environment(\.dismiss) var dismiss
    @Environment(\.motionEnabled) var motion
    let item: MediaItem

    indirect enum Page: Hashable {
        case actions, seasons
        case episodes(Int)
        case versions(SheetSearchTarget, back: Page)
    }

    @State var page: Page = .actions
    @State var detail: ItemDetail?
    @State var loadFailed = false
    /// Set only when THIS open parked a single-version target waiting for the detail.
    @State var pendingLaunch = false
    @State private var contentHeight: CGFloat = 360

    var monitored: Bool { item.monitored ?? true }
    var isSeries: Bool { item.kind != .movie }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.trailing, 30)
                .padding(.bottom, 16)
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
        .presentationDetents([.height(min(contentHeight + 124, 660)), .large])
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

    func go(_ next: Page) {
        withAnimation(motion ? .timingCurve(0.2, 0.9, 0.25, 1, duration: 0.26) : nil) { page = next }
    }

    // MARK: Header

    /// `.ps-head`: a small shelf thumbnail, the title, `Series · 2024`, and one
    /// lit tier chip per version with its status mark (`HD ✓  4K 0/10`).
    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            PosterImage(url: TMDBImage.resized(item.posterUrl, to: "w154"))
                .aspectRatio(2 / 3, contentMode: .fill)
                .frame(width: 44, height: 66)
                .shelfPoster(radius: 5, shadow: false)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.txt)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.mut)
                    .lineLimit(1)
                let rails = item.rails
                FlowRow(spacing: 10, lineSpacing: 6) {
                    ForEach(item.editions.indices, id: \.self) { index in
                        versionPair(item.editions[index], rail: rails[index])
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var subtitle: String {
        var parts = [isSeries ? "Series" : "Movie"]
        if let year = item.year { parts.append(String(year)) }
        if !monitored { parts.append("Unmonitored") }
        return parts.joined(separator: " · ")
    }

    /// One version: its cut (when it has one), the lit tier chip, and the
    /// status mark in the status colour (`✓`, `3/10`, `↓`, `↑`, `wanted`).
    private func versionPair(_ edition: Edition, rail: Rail) -> some View {
        let color: Color?
        switch rail.state {
        case .owned: color = Theme.done
        case .downloading: color = Theme.grab
        case .upgrading: color = Theme.edition
        case .wanted: color = Theme.miss
        default: color = nil
        }
        var mark = ""
        var spoken = ""
        if isSeries, let total = edition.total, total > 0 {
            let have = edition.have ?? 0
            mark = have >= total ? "✓" : "\(have)/\(total)"
            spoken = "\(have) of \(total)"
        } else {
            switch rail.state {
            case .owned: mark = "✓"
            case .downloading: mark = "↓"
            case .upgrading: mark = "↑"
            case .wanted: mark = "wanted"
            default: mark = ""
            }
            spoken = rail.state.label
        }
        let cut = edition.movieEdition ?? ""
        return HStack(spacing: 4) {
            if !cut.isEmpty {
                Text(cut).font(.system(size: 12)).foregroundStyle(Theme.mut).lineLimit(1)
            }
            TierPill(tier: edition.tier)
            if !mark.isEmpty {
                Text(mark)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(color ?? Theme.mut)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(cut.isEmpty ? "" : "\(cut) ")\(edition.tier.pill), \(spoken)")
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

    func run(_ action: @escaping () -> Void) -> () -> Void {
        { dismiss(); action() }
    }

    private var actionsPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            SheetPrimaryButton(label: "Automatic search", icon: "magnifyingglass",
                               action: run { model.autoSearch(item.id) })
            SheetList {
                SheetRow(index: 1, label: "Interactive search", icon: "person",
                         chevron: isSeries || item.editions.count > 1, action: startInteractive)
                SheetSeparator()
                SheetToggleRow(index: 2, label: "Monitor", icon: monitored ? "bookmark.fill" : "bookmark",
                               isOn: Binding(get: { monitored }, set: { on in
                                   dismiss()
                                   model.setMonitored(item.id, title: item.title, monitored: on)
                               }))
                SheetSeparator()
                SheetRow(index: 3, label: "Refresh metadata", icon: "arrow.clockwise",
                         action: run { model.refreshMetadata(item.id, title: item.title) })
                SheetSeparator()
                SheetRow(index: 4, label: "Edit…", icon: "pencil", action: run { model.edit(item.id) })
                SheetSeparator()
                SheetRow(index: 5, label: "Delete…", icon: "trash", tone: .danger,
                         action: run { model.confirmDelete(item.id, title: item.title) })
            }
        }
        .padding(.bottom, 8)
    }

    private func startInteractive() {
        if isSeries { go(.seasons) } else { choose(.item, back: .actions) }
    }

    /// One version → search now; several → pick the version.
    func choose(_ target: SheetSearchTarget, back: Page) {
        if let detail, detail.editions.count == 1 {
            launch(detail, target, versionId: detail.editions[0].id)
            return
        }
        pendingLaunch = detail == nil
        go(.versions(target, back: back))
    }

    func launch(_ data: ItemDetail, _ target: SheetSearchTarget, versionId: Int, all: Bool = false) {
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
}
