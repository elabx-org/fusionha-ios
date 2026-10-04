import SwiftUI
import FusionhaKit

extension WantedState {
    var title: String {
        switch self {
        case .missing: return "Missing"
        case .cutoffUnmet: return "Cutoff Unmet"
        case .upcoming: return "Upcoming"
        }
    }

    var color: Color {
        switch self {
        case .missing: return Theme.miss
        case .cutoffUnmet: return Theme.edition
        case .upcoming: return Theme.unaired
        }
    }

    var explainer: (lead: String, bold: String, tail: String) {
        switch self {
        case .missing: return ("Monitored editions with ", "no file yet", ". Search runs the engine across every monitored edition.")
        case .cutoffUnmet: return ("Editions with a file ", "below their profile's cutoff", ". Search looks for an upgrade.")
        case .upcoming: return ("Monitored editions ", "not released yet", ". They're grabbed automatically once available.")
        }
    }
}

/// The web's Wanted page: totals card, state chips, search and per-title cards.
struct WantedView: View {
    @Environment(AppModel.self) private var model
    @State private var state: WantedState = .missing
    @State private var page: WantedPage?
    @State private var counts: WantedPage?
    @State private var query = ""
    @State private var error: String?
    @State private var searchingAll = false
    @State private var searchSent = false

    var body: some View {
        Screen(showsAdd: true) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PageHeader(title: "Wanted", subtitle: subtitle, stacked: true)
                    statsCard
                    chips
                    WebSearchField(placeholder: "Search by title…", text: $query)
                    if state != .upcoming { searchAllButton }
                    explainer
                    list
                }
                .padding(.horizontal, 10)
                .padding(.top, 14)
                .padding(.bottom, 90)
            }
            .refreshable { await load() }
        }
        .task(id: "\(state.rawValue)|\(query)") {
            if !query.isEmpty { try? await Task.sleep(for: .milliseconds(250)) }
            await load()
        }
    }

    private var totalTitles: Int { counts?.total ?? 0 }

    private var subtitle: String {
        guard let c = counts else { return " " }
        return "\(c.total) wanted titles · \(c.missingTitles ?? 0) missing, \(c.cutoffUnmetTitles ?? 0) below cutoff, \(c.upcomingTitles ?? 0) upcoming"
    }

    private func titles(_ s: WantedState) -> Int {
        switch s {
        case .missing: return counts?.missingTitles ?? 0
        case .cutoffUnmet: return counts?.cutoffUnmetTitles ?? 0
        case .upcoming: return counts?.upcomingTitles ?? 0
        }
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(totalTitles)")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.txt)
                EyebrowLabel(text: "Wanted titles")
            }
            HStack(alignment: .top, spacing: 18) {
                ForEach(WantedState.allCases, id: \.self) { s in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(titles(s))")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.txt)
                        RailBar(progress: totalTitles > 0 ? titles(s) * 100 / totalTitles : 0, color: s.color, state: .partial)
                            .frame(height: 4)
                        EyebrowLabel(text: s == .cutoffUnmet ? "Below cutoff" : s.title)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(18)
        .panel(Theme.card, radius: 18)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WantedState.allCases, id: \.self) { s in
                    DotChip(label: s.title, count: titles(s), dot: s.color, selected: state == s, topAccent: s.color) {
                        withAnimation(.snappy) { state = s }
                    }
                }
            }
        }
        .scrollClipDisabled()
    }

    private var searchAllButton: some View {
        Button {
            Task {
                searchingAll = true
                if state == .missing { try? await model.client?.searchMissing() } else { try? await model.client?.searchCutoffUnmet() }
                searchingAll = false
                searchSent = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: searchSent ? "checkmark" : "magnifyingglass")
                    .contentTransition(.symbolEffect(.replace))
                Text(searchSent ? "Search started" : (state == .missing ? "Search all missing" : "Search all cutoff unmet"))
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(searchSent ? Theme.done : Theme.txt)
            .padding(.horizontal, 14)
            .frame(height: 40)
        }
        .buttonStyle(.plain)
        .disabled(searchingAll)
        .sensoryFeedback(.success, trigger: searchSent)
        .onChange(of: state) { searchSent = false }
    }

    private var explainer: some View {
        let e = state.explainer
        return (Text(e.lead) + Text(e.bold).bold().foregroundColor(Theme.txt) + Text(" — ")
            + Text(Image(systemName: "circle.fill")).font(.system(size: 8)).foregroundColor(state.color)
            + Text(" \(state.title.lowercased())") + Text(e.tail))
            .font(.system(size: 14))
            .foregroundStyle(Theme.mut)
    }

    @ViewBuilder
    private var list: some View {
        if let items = page?.items, !items.isEmpty {
            LazyVStack(spacing: 12) {
                ForEach(items) { WantedCard(item: $0, state: state) }
            }
        } else if page == nil && error == nil {
            ProgressView().tint(Theme.mut).frame(maxWidth: .infinity).padding(.top, 40)
        } else if error != nil {
            EmptyBox(message: "Wanted could not be loaded. Check the backend and try again.")
        } else {
            EmptyBox(message: query.isEmpty ? "Nothing \(state.title.lowercased()) right now." : "No wanted titles match “\(query)”.")
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            let result = try await client.wanted(state: state, query: query)
            page = result
            if query.isEmpty { counts = result } else if counts == nil { counts = result }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct WantedCard: View {
    @Environment(AppModel.self) private var model
    let item: WantedItem
    let state: WantedState
    @State private var searched = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                thumb
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(item.title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(2)
                        kindBadge
                    }
                    Text(state.title).font(.system(size: 14, weight: .bold)).foregroundStyle(state.color)
                    ForEach(item.editions) { edition in
                        HStack(spacing: 6) {
                            Circle().fill(state.color).frame(width: 7, height: 7)
                            Text(edition.tier.chipLabel)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(edition.tier.color)
                        }
                        .padding(.horizontal, 9)
                        .frame(height: 26)
                        .overlay(Capsule().strokeBorder(Theme.line))
                        if let info = info(edition) {
                            Text(info)
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundStyle(Theme.mut)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)

            Rectangle().fill(Theme.line).frame(height: 1)
            HStack(spacing: 22) {
                Button { model.open(item.id) } label: {
                    Label("Open in library", systemImage: "arrow.up.right.square")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.mut)
                }
                Button {
                    Task {
                        try? await model.client?.searchItem(id: item.id)
                        searched = true
                    }
                } label: {
                    Image(systemName: searched ? "checkmark" : "magnifyingglass")
                        .foregroundStyle(searched ? Theme.done : Theme.mut)
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel("Search")
                Spacer()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .frame(height: 48)

            let episodes = item.editions.flatMap { $0.missingEpisodes ?? [] }
            if !episodes.isEmpty {
                Rectangle().fill(Theme.line).frame(height: 1)
                ForEach(episodes.prefix(8)) { ep in
                    HStack(spacing: 14) {
                        Text(ep.code).font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundStyle(Theme.txt)
                        Text(ep.title ?? "TBA").font(.system(size: 14)).foregroundStyle(Theme.mut).lineLimit(1)
                        Spacer(minLength: 0)
                        Text(Format.shortDate(ep.airDate))
                            .font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.dim)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    if ep.id != episodes.prefix(8).last?.id {
                        Rectangle().fill(Theme.line).frame(height: 1).padding(.horizontal, 16)
                    }
                }
            }
        }
        .background(
            LinearGradient(colors: [state.color.opacity(0.07), Theme.card], startPoint: .topLeading, endPoint: .center),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.line))
        .contentShape(Rectangle())
    }

    private var thumb: some View {
        PosterImage(url: TMDBImage.resized(item.posterUrl, to: "w154"))
            .overlay {
                if item.posterUrl == nil {
                    Text(String(item.title.prefix(1))).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.mut)
                }
            }
            .frame(width: 36, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Theme.line))
    }

    private var kindBadge: some View {
        let label = item.isAnime ? "Anime" : (item.kind == .movie ? "Movie" : "Series")
        let color = item.isAnime ? Theme.anime : (item.kind == .movie ? Theme.kindMovie : Theme.cyan)
        return Text(label.uppercased())
            .font(.system(size: 10, weight: .heavy))
            .tracking(1)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.1), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.45)))
    }

    private func info(_ edition: WantedEdition) -> String? {
        var parts: [String] = []
        if let count = edition.missingEpisodeCount, count > 0 {
            parts.append("\(count) episode\(count == 1 ? "" : "s") aired")
        }
        if let latest = Format.day(edition.latestAired) {
            parts.append("latest \(latest.formatted(.relative(presentation: .named)))")
        }
        if let quality = edition.currentQuality {
            parts.append("has \(quality.replacingOccurrences(of: "_", with: " "))")
        }
        if edition.neverSearched == true {
            parts.append("never searched")
        } else if let last = edition.lastSearch {
            parts.append("searched \(Format.relative(last))")
        }
        return parts.isEmpty ? nil : "· " + parts.joined(separator: " · ")
    }
}
