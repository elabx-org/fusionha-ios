import SwiftUI
import FusionhaKit

/// The web's "Add title" sheet: search TMDB, pick a title, then configure each
/// edition (HD by default, 4K opt-in) with its root folder and quality profile.
/// Requester accounts get a Request flow instead.
struct AddTitleSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var kind: SearchKind = .all
    @State private var query = ""
    @State private var results: [MediaSearchResult] = []
    @State private var searching = false
    @State private var picked: MediaSearchResult?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let picked {
                    if model.requestScoped {
                        RequestConfigurator(result: picked) { dismiss() }
                    } else {
                        EditionConfigurator(result: picked) { id in
                            dismiss()
                            Task {
                                await model.loadLibrary()
                                model.open(id)
                            }
                        }
                    }
                } else {
                    SegmentedPills(options: SearchKind.allCases.map { ($0, $0.title) }, selection: $kind, fill: true)
                    WebSearchField(placeholder: "Search movies, series & anime", text: $query)
                    resultsList
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.panel)
        .onAppear {
            picked = model.addPrefill
            model.addPrefill = nil
        }
        .task(id: "\(query)|\(kind.rawValue)") {
            let term = query.trimmingCharacters(in: .whitespaces)
            guard term.count >= 2 else { results = []; return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let client = model.client else { return }
            searching = true
            results = (try? await client.search(term: term, kind: kind)) ?? []
            searching = false
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.requestScoped ? "Request title" : "Add title")
                    .font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.txt)
                Text(picked == nil ? "Search TMDB, then configure each edition" : "Configure the editions to track")
                    .font(.system(size: 14)).foregroundStyle(Theme.mut)
            }
            Spacer()
            if picked != nil {
                Button("Back") { withAnimation(.snappy) { picked = nil } }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.mut)
            }
        }
    }

    @ViewBuilder
    private var resultsList: some View {
        if query.trimmingCharacters(in: .whitespaces).count < 2 {
            Text("Type at least two letters to search TMDB.")
                .font(.system(size: 14)).foregroundStyle(Theme.mut)
                .frame(maxWidth: .infinity).padding(.top, 20)
        } else if searching && results.isEmpty {
            ProgressView().tint(Theme.mut).frame(maxWidth: .infinity).padding(.top, 20)
        } else if results.isEmpty {
            EmptyBox(message: "Nothing on TMDB matches “\(query)”.")
        } else {
            LazyVStack(spacing: 10) {
                ForEach(results) { result in
                    Button {
                        if result.inLibrary, let id = result.libraryItemId, !model.requestScoped {
                            dismiss()
                            model.open(id)
                        } else {
                            withAnimation(.snappy) { picked = result }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            PosterImage(url: TMDBImage.resized(result.posterUrl, to: "w154"))
                                .frame(width: 44, height: 66)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                                HStack(spacing: 6) {
                                    if let year = result.year { Text(String(year)) }
                                    if result.isAnime { AnimeChip() } else { KindGlyph(kind: result.kind) }
                                }
                                .font(.system(size: 12)).foregroundStyle(Theme.mut)
                                if let overview = result.overview {
                                    Text(overview).font(.system(size: 12)).foregroundStyle(Theme.dim).lineLimit(2)
                                }
                            }
                            Spacer(minLength: 0)
                            if result.inLibrary {
                                Text("In library").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.done)
                            } else {
                                Image(systemName: "chevron.right").foregroundStyle(Theme.dim)
                            }
                        }
                        .padding(10)
                        .panel(Theme.card, radius: 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// The picked title plus one row per tier: on/off, root folder, profile.
private struct EditionConfigurator: View {
    @Environment(AppModel.self) private var model
    let result: MediaSearchResult
    let added: (Int) -> Void

    @State private var roots: [RootFolder] = []
    @State private var profiles: [QualityProfile] = []
    @State private var hd = TierConfig(enabled: true)
    @State private var uhd = TierConfig(enabled: false)
    @State private var searchNow = true
    @State private var adding = false
    @State private var error: String?

    struct TierConfig {
        var enabled: Bool
        var rootId: Int?
        var profileId: Int?
    }

    private var profileKind: String { result.isAnime ? "anime" : result.kind.rawValue }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PickedTitle(result: result)
            tierRow(.hd, config: $hd)
            tierRow(.uhd, config: $uhd)
            Toggle(isOn: $searchNow) {
                Text("Search for releases now").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt)
            }
            .tint(Theme.indigo)
            .padding(14)
            .panel(Theme.card, radius: 12)
            if let error {
                Text(error).font(.system(size: 13)).foregroundStyle(Theme.danger)
            }
            Button {
                Task { await add() }
            } label: {
                Group {
                    if adding { ProgressView().tint(Theme.bg) } else { Text("Add to library") }
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.bg)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Theme.fusion, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(adding || !canAdd)
            .opacity(canAdd ? 1 : 0.5)
        }
        .task { await loadOptions() }
    }

    private var canAdd: Bool {
        let tiers = [hd, uhd].filter(\.enabled)
        return !tiers.isEmpty && tiers.allSatisfy { $0.rootId != nil && $0.profileId != nil }
    }

    private func tierRow(_ tier: QualityTier, config: Binding<TierConfig>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: config.enabled) {
                HStack(spacing: 8) {
                    TierPill(tier: tier, large: true)
                    Text(tier == .hd ? "Default edition" : "Track a 4K edition too")
                        .font(.system(size: 13)).foregroundStyle(Theme.mut)
                }
            }
            .tint(tier.color)
            if config.wrappedValue.enabled {
                picker("Root folder", selection: config.rootId, options: roots.map { ($0.id, $0.path) })
                picker("Quality profile", selection: config.profileId,
                       options: profiles.filter { $0.mediaKind == nil || $0.mediaKind == result.kind.rawValue }
                           .map { ($0.id, $0.name) })
            }
        }
        .padding(14)
        .panel(Theme.card, radius: 12)
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12)
                .fill(config.wrappedValue.enabled ? tier.color : .clear).frame(height: 2).padding(.horizontal, 1)
        }
    }

    private func picker(_ label: String, selection: Binding<Int?>, options: [(Int, String)]) -> some View {
        HStack {
            EyebrowLabel(text: label)
            Spacer()
            Menu {
                ForEach(options.indices, id: \.self) { index in
                    Button(options[index].1) { selection.wrappedValue = options[index].0 }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(options.first { $0.0 == selection.wrappedValue }?.1 ?? "Choose…")
                        .font(.system(size: 13, design: .monospaced))
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 10))
                }
                .foregroundStyle(Theme.txt)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .panel(Theme.panel2, radius: 8)
            }
        }
    }

    private func loadOptions() async {
        guard let client = model.client else { return }
        async let rootsCall = client.rootFolders()
        async let profilesCall = client.qualityProfiles()
        async let defaultsCall = client.addDefaults()
        roots = (try? await rootsCall) ?? []
        profiles = (try? await profilesCall) ?? []
        let defaults = (try? await defaultsCall) ?? []
        hd = preset(.hd, current: hd, defaults: defaults)
        uhd = preset(.uhd, current: uhd, defaults: defaults)
    }

    /// Saved add-defaults first, else a root whose path matches the kind and tier
    /// (`/movies-4k`, `/tv`, `/anime`), else the first one.
    private func preset(_ tier: QualityTier, current: TierConfig, defaults: [AddDefaultSlot]) -> TierConfig {
        var config = current
        let slot = defaults.first { $0.profileKind == profileKind && $0.tier == tier }
        let wants4k = tier == .uhd
        let kindWords = result.isAnime ? ["anime"] : (result.kind == .movie ? ["movie", "film"] : ["tv", "series", "show"])
        let byPath = roots.first { root in
            let p = root.path.lowercased()
            return kindWords.contains { p.contains($0) } && (p.contains("4k") || p.contains("2160")) == wants4k
        }
        config.rootId = slot?.rootFolderId ?? byPath?.id ?? roots.first?.id
        let tierWords = wants4k ? ["4k", "2160", "uhd"] : ["1080", "hd"]
        let kindProfiles = profiles.filter { $0.mediaKind == nil || $0.mediaKind == result.kind.rawValue }
        let byName = kindProfiles.first { p in
            let n = p.name.lowercased()
            return tierWords.contains { n.contains($0) } && (wants4k || !n.contains("ultra"))
        }
        config.profileId = slot?.qualityProfileId ?? byName?.id ?? kindProfiles.first?.id
        return config
    }

    private func add() async {
        guard let client = model.client else { return }
        adding = true
        defer { adding = false }
        var editions: [EditionCreate] = []
        for (tier, config) in [(QualityTier.hd, hd), (.uhd, uhd)] where config.enabled {
            guard let root = config.rootId, let profile = config.profileId else { continue }
            editions.append(EditionCreate(tier: tier, rootFolderId: root, qualityProfileId: profile))
        }
        do {
            let item = try await client.add(LibraryAddRequest(result: result, editions: editions, searchNow: searchNow))
            added(item.id)
        } catch {
            self.error = "Couldn't add this title. \(error.localizedDescription)"
        }
    }
}

private struct RequestConfigurator: View {
    @Environment(AppModel.self) private var model
    let result: MediaSearchResult
    let done: () -> Void
    @State private var tier: QualityTier = .hd
    @State private var sending = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PickedTitle(result: result)
            SegmentedPills(options: [(QualityTier.hd, "HD·1080p"), (.uhd, "UHD·4K")], selection: $tier, fill: true)
            if let error {
                Text(error).font(.system(size: 13)).foregroundStyle(Theme.danger)
            }
            Button {
                Task {
                    sending = true
                    do {
                        try await model.client?.request(MediaRequestCreate(tmdbId: result.tmdbId, kind: result.kind, tier: tier))
                        done()
                    } catch {
                        self.error = "Couldn't send the request. \(error.localizedDescription)"
                    }
                    sending = false
                }
            } label: {
                Text(sending ? "Requesting…" : "Request")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.bg)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Theme.fusion, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(sending)
        }
    }
}

private struct PickedTitle: View {
    let result: MediaSearchResult

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            PosterImage(url: TMDBImage.resized(result.posterUrl, to: "w342"))
                .frame(width: 72, height: 108)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.line))
            VStack(alignment: .leading, spacing: 6) {
                Text(result.title).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.txt)
                HStack(spacing: 6) {
                    if let year = result.year { Text(String(year)) }
                    if result.isAnime { AnimeChip() } else { KindGlyph(kind: result.kind) }
                }
                .font(.system(size: 13)).foregroundStyle(Theme.mut)
                if let overview = result.overview {
                    Text(overview).font(.system(size: 13)).foregroundStyle(Theme.mut).lineLimit(4)
                }
            }
        }
    }
}
