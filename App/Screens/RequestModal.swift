import SwiftUI
import FusionhaKit

// MARK: - RequestModal

struct RequestModal: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let pick: MediaSearchResult
    let onDone: () -> Void

    @State private var offer: OfferableEditions?
    @State private var offerFailed = false
    @State private var preview: MediaPreviewDetail?
    @State private var selectedTiers: Set<QualityTier> = []
    @State private var selSeasons: Set<Int> = []
    @State private var selEpisodes: Set<EpisodeRef> = []
    @State private var openSeasons: Set<Int> = []
    @State private var episodeTitles: [Int: [Int: String]] = [:]
    @State private var note = ""
    @State private var sending = false
    @State private var previewLoaded = false

    private var isSeries: Bool { pick.kind == .series }
    private var editionsToSend: [QualityTier] {
        guard let offer else { return [] }
        if offer.isAuto { return offer.autoEditions }
        return [QualityTier.hd, .uhd].filter { selectedTiers.contains($0) }
    }
    private var nothingOfferable: Bool {
        guard let offer else { return false }
        return offer.isAuto ? offer.autoEditions.isEmpty : offer.editions.isEmpty
    }
    private var canSubmit: Bool { offer != nil && !nothingOfferable && !editionsToSend.isEmpty && !sending }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    artPane
                    optionsPane
                }
            }
            footer
        }
        .background(Theme.panel)
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.mut)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .padding(.top, 14).padding(.trailing, 14)
            .accessibilityLabel("Close")
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.panel)
        .presentationCornerRadius(14)
        .task { await load() }
    }

    private func load() async {
        guard let client = model.client else { return }
        async let offerCall = client.offerableEditions(kind: pick.kind, tmdbId: pick.tmdbId)
        async let previewCall = client.previewDetail(kind: pick.previewKind, tmdbId: pick.tmdbId)
        do {
            let loaded = try await offerCall
            offer = loaded
            if !loaded.isAuto { selectedTiers = Set(loaded.editions) }
        } catch {
            offerFailed = true
        }
        preview = try? await previewCall
        previewLoaded = true
    }

    // MARK: Art pane

    private var artPane: some View {
        let kindColor = pick.kind == .movie ? Theme.kindMovie : Theme.kindSeries
        return VStack(spacing: 12) {
            Text(pick.kind == .movie ? "MOVIE · REQUEST" : "SERIES · REQUEST")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(kindColor)
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(kindColor.opacity(0.15), in: Capsule())
            Color.clear
                .aspectRatio(2 / 3, contentMode: .fit)
                .frame(maxWidth: 190)
                .overlay { DiscoverArt(url: TMDBImage.resized(preview?.posterUrl ?? pick.posterUrl, to: "w780")) }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
                .shadow(color: .black.opacity(0.5), radius: 16, y: 12)
            Text(preview?.title ?? pick.title)
                .font(.system(size: 20, weight: .heavy)).tracking(-0.2)
                .foregroundStyle(Theme.txt)
                .multilineTextAlignment(.center)
            if let facts {
                Text(facts).font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            }
            if let genres = preview?.genres, !genres.isEmpty {
                HStack(spacing: 6) {
                    ForEach(genres.prefix(4), id: \.self) { genre in
                        Text(genre).font(.system(size: 11)).foregroundStyle(Theme.dim)
                            .padding(.horizontal, 9).padding(.vertical, 2)
                            .overlay(Capsule().strokeBorder(Theme.line))
                    }
                }
            }
            if let overview = preview?.overview ?? pick.overview, !overview.isEmpty {
                Text(overview).font(.system(size: 12)).foregroundStyle(Theme.dim)
                    .lineSpacing(3).lineLimit(6)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20).padding(.top, 46).padding(.bottom, 20)
        .background(LinearGradient(colors: [kindColor.opacity(pick.kind == .movie ? 0.10 : 0.12), .clear],
                                   startPoint: .top, endPoint: .bottom))
        .background(Theme.panel)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    private var facts: String? {
        var parts: [String] = []
        if let year = preview?.year ?? pick.displayYear { parts.append(String(year)) }
        if isSeries {
            let count = (preview?.seasons ?? []).filter { $0.seasonNumber > 0 }.count
            if count > 0 { parts.append(count == 1 ? "1 season" : "\(count) seasons") }
        } else if let runtime = preview?.runtime, runtime > 0 {
            parts.append("\(runtime) min")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: Options pane

    private var optionsPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                DialogSectionLabel(text: "Editions")
                editions
            }
            if isSeries {
                VStack(alignment: .leading, spacing: 10) {
                    DialogSectionLabel(text: "Seasons & episodes")
                    seasons
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                DialogSectionLabel(text: "Note for the approver", trailing: "optional")
                TextField("", text: $note, prompt: Text("Anything the approver should know…").foregroundStyle(Theme.dim),
                          axis: .vertical)
                    .lineLimit(3...6)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.txt)
                    .padding(11)
                    .frame(minHeight: 64, alignment: .topLeading)
                    .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Theme.line))
            }
        }
        .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 8)
    }

    @ViewBuilder
    private var editions: some View {
        if offerFailed {
            dashed("Could not load your access — try again.")
        } else if let offer {
            if nothingOfferable {
                dashed("Nothing to request — you already have every edition you can access.", color: Theme.mut, centred: true)
            } else if offer.isAuto {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lock").font(.system(size: 14)).foregroundStyle(Theme.dim)
                        (Text("Quality is set by the admin. This request goes to your ")
                         + Text(offer.autoEditions.map(\.chipLabel).joined(separator: " + ")).foregroundColor(Theme.txt).fontWeight(.semibold)
                         + Text(" library — you don't choose per-request."))
                            .font(.system(size: 13)).foregroundStyle(Theme.mut)
                    }
                    HStack(spacing: 6) {
                        ForEach(offer.autoEditions, id: \.self) { tier in
                            Text(tier.chipLabel).font(.system(size: 11, weight: .bold)).foregroundStyle(tier.color)
                                .padding(.horizontal, 9).padding(.vertical, 3)
                                .background(tier.color.opacity(0.15), in: Capsule())
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 13)
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(offer.editions, id: \.self) { tier in
                        let selected = selectedTiers.contains(tier)
                        Button {
                            if selected { selectedTiers.remove(tier) } else { selectedTiers.insert(tier) }
                        } label: {
                            HStack(spacing: 13) {
                                WebCheckSquare(checked: selected, color: tier.color)
                                RoundedRectangle(cornerRadius: 3).fill(tier.color).frame(width: 9, height: 9)
                                Text(tier.chipLabel).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(Theme.txt)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 13)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(selected ? tier.color.opacity(0.55) : Theme.line))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(DiscoverPressStyle())
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                    Text("Pick one or both — HD and 4K are separate libraries, each grabbed & tracked on its own.")
                        .font(.system(size: 11.5)).foregroundStyle(Theme.dim)
                }
            }
        } else {
            dashed("Checking what you can request…")
        }
    }

    private func dashed(_ text: String, color: Color = Theme.dim, centred: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 12.5))
            .foregroundStyle(color)
            .multilineTextAlignment(centred ? .center : .leading)
            .frame(maxWidth: .infinity, alignment: centred ? .center : .leading)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
    }

    @ViewBuilder
    private var seasons: some View {
        if !previewLoaded {
            Text("Loading seasons…").font(.system(size: 12.5)).foregroundStyle(Theme.dim)
        } else if let list = preview?.seasons, !list.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(list) { season in seasonRow(season) }
                Text("Tick a whole season, or expand for specific episodes. Select nothing to request the whole series.")
                    .font(.system(size: 11.5)).foregroundStyle(Theme.dim)
                    .padding(.top, 1)
            }
        } else {
            Text("No season data available.").font(.system(size: 12.5)).foregroundStyle(Theme.dim)
        }
    }

    private func seasonRow(_ season: PreviewSeason) -> some View {
        let n = season.seasonNumber
        let full = selSeasons.contains(n)
        let open = openSeasons.contains(n)
        let label = n == 0 ? "Specials" : "Season \(n)"
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button { toggleSeason(season) } label: {
                    WebCheckSquare(checked: full).frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Select \(label)")
                Button {
                    withAnimation(DiscoverMotion.reduced(reduceMotion) ? nil : .easeOut(duration: 0.2)) {
                        if open { openSeasons.remove(n) } else { openSeasons.insert(n) }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(label).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                        Spacer(minLength: 0)
                        Text("\(season.episodeCount) eps").font(.system(size: 11)).foregroundStyle(Theme.dim)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.mut)
                            .rotationEffect(.degrees(open ? 90 : 0))
                    }
                    .padding(.trailing, 13)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(open ? "Collapse" : "Expand") \(label)")
            }
            if open {
                VStack(spacing: 0) {
                    ForEach(1...max(1, season.episodeCount), id: \.self) { e in
                        let selected = full || selEpisodes.contains(EpisodeRef(season: n, episode: e))
                        Button { toggleEpisode(season, e) } label: {
                            HStack(spacing: 10) {
                                WebCheckSquare(checked: selected, size: 18)
                                Text("S\(n)·E\(e)").font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.mut)
                                    .frame(minWidth: 56, alignment: .leading)
                                Text(episodeTitles[n]?[e] ?? "Episode \(e)")
                                    .font(.system(size: 12.5)).foregroundStyle(selected ? Theme.txt : Theme.mut)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.leading, 38).padding(.trailing, 13).padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Theme.panel2)
                .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
                .transition(.opacity)
                .task {
                    guard episodeTitles[n] == nil, let client = model.client else { return }
                    let eps = (try? await client.previewSeason(kind: pick.previewKind, tmdbId: pick.tmdbId, season: n)) ?? []
                    var map: [Int: String] = [:]
                    for ep in eps { if let t = ep.title { map[ep.episodeNumber] = t } }
                    episodeTitles[n] = map
                }
            }
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
            .strokeBorder(full ? Theme.indigo.opacity(0.4) : Theme.line))
    }

    private func toggleSeason(_ season: PreviewSeason) {
        let n = season.seasonNumber
        if selSeasons.contains(n) {
            selSeasons.remove(n)
        } else {
            selSeasons.insert(n)
            selEpisodes = selEpisodes.filter { $0.season != n }
        }
    }

    private func toggleEpisode(_ season: PreviewSeason, _ e: Int) {
        let n = season.seasonNumber
        let ref = EpisodeRef(season: n, episode: e)
        if selSeasons.contains(n) {
            selSeasons.remove(n)
            for other in 1...max(1, season.episodeCount) where other != e {
                selEpisodes.insert(EpisodeRef(season: n, episode: other))
            }
        } else if selEpisodes.contains(ref) {
            selEpisodes.remove(ref)
        } else {
            selEpisodes.insert(ref)
            let all = (1...max(1, season.episodeCount)).allSatisfy { selEpisodes.contains(EpisodeRef(season: n, episode: $0)) }
            if all {
                selSeasons.insert(n)
                selEpisodes = selEpisodes.filter { $0.season != n }
            }
        }
    }

    // MARK: Footer

    private var summary: String {
        if offer == nil && !offerFailed { return "Checking what you can request…" }
        if offerFailed { return "Could not check available editions." }
        if nothingOfferable { return "Nothing to request — you already have every edition you can access." }
        if editionsToSend.isEmpty { return "Select an edition" }
        let tiers = editionsToSend.map(\.chipLabel).joined(separator: " + ")
        let title = preview?.title ?? pick.title
        guard isSeries else { return "Requesting \(title) · \(tiers)" }
        var parts: [String] = []
        if !selSeasons.isEmpty { parts.append("\(selSeasons.count) season\(selSeasons.count > 1 ? "s" : "")") }
        if !selEpisodes.isEmpty { parts.append("\(selEpisodes.count) episode\(selEpisodes.count > 1 ? "s" : "")") }
        return "Requesting \(title) · \(tiers) · \(parts.isEmpty ? "Whole series" : parts.joined(separator: " + "))"
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text(summary).font(.system(size: 12.5)).foregroundStyle(Theme.mut).lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(sending ? "Requesting…" : "Request") { Task { await submit() } }
                .buttonStyle(.discover(.primary))
                .disabled(!canSubmit)
        }
        .padding(.horizontal, 22).padding(.vertical, 14)
        .background(Theme.panel)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    private func submit() async {
        guard canSubmit, let client = model.client else { return }
        sending = true
        defer { sending = false }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let episodes = selEpisodes.sorted { ($0.season, $0.episode) < ($1.season, $1.episode) }
        do {
            try await client.createRequest(RequestCreateBody(
                tmdbId: pick.tmdbId, kind: pick.kind, editions: editionsToSend,
                seasons: isSeries ? selSeasons.sorted() : [], episodes: isSeries ? episodes : [],
                note: trimmed.isEmpty ? nil : trimmed))
            DiscoverToasts.shared.show(.success, "\(preview?.title ?? pick.title) requested")
            onDone()
            dismiss()
        } catch {
            DiscoverToasts.shared.error("Could not submit request", error)
        }
    }
}
