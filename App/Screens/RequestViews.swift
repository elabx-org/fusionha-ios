import SwiftUI
import FusionhaKit

// Requests: the RequestModal (request a title), the Requests tab (approval
// queue for approvers, "My requests" for everyone else), the Approve and
// Reject dialogs, and the Add-collection sheet (`components/discover/*`).

// MARK: - Preview cache (titles/posters for request rows)

@MainActor
@Observable
final class PreviewCache {
    static let shared = PreviewCache()
    private(set) var entries: [String: MediaPreviewDetail] = [:]
    private var inflight: Set<String> = []

    func get(_ kind: PreviewKind, _ tmdbId: Int) -> MediaPreviewDetail? { entries["\(kind.rawValue)-\(tmdbId)"] }

    func load(_ client: APIClient?, kind: PreviewKind, tmdbId: Int) async {
        let key = "\(kind.rawValue)-\(tmdbId)"
        guard let client, entries[key] == nil, !inflight.contains(key) else { return }
        inflight.insert(key)
        defer { inflight.remove(key) }
        if let detail = try? await client.previewDetail(kind: kind, tmdbId: tmdbId) {
            entries[key] = detail
        }
    }
}

// MARK: - Edition defaults (components/library/edition-defaults.ts)

struct ApproveTierConfig: Equatable {
    var enabled: Bool
    var rootId: Int?
    var profileId: Int?
}

enum DiscoverEditionDefaults {
    static func rootMatchesKind(_ path: String, kind: MediaKind) -> Bool {
        let p = path.lowercased()
        let words = kind == .series ? ["tv", "anime", "series", "show"] : ["movie", "film"]
        return words.contains { p.contains($0) }
    }

    static func rootIs4k(_ path: String) -> Bool {
        let p = path.lowercased()
        return ["4k", "2160", "uhd"].contains { p.contains($0) }
    }

    static func profileIs4k(_ profile: QualityProfile) -> Bool {
        let n = profile.name.lowercased()
        if ["4k", "2160", "uhd", "ultra"].contains(where: { n.contains($0) }) { return true }
        return (profile.allowedQualities ?? []).contains { q in
            let l = q.lowercased()
            return l.contains("2160") || l.contains("4k") || l.contains("uhd")
        }
    }

    /// `profilesForItem`: profiles with no kind, or the item's kind(s).
    static func profiles(_ all: [QualityProfile], kind: MediaKind, isAnime: Bool) -> [QualityProfile] {
        let kinds: Set<String> = isAnime ? ["anime", kind.rawValue] : [kind.rawValue]
        return all.filter { $0.mediaKind == nil || kinds.contains($0.mediaKind!) }
    }

    static func resolve(_ tier: QualityTier, kind: MediaKind, isAnime: Bool, roots: [RootFolder],
                        profiles: [QualityProfile], defaults: [AddDefaultSlot]) -> (Int?, Int?) {
        let profileKind = isAnime ? "anime" : kind.rawValue
        let slot = defaults.first { $0.profileKind == profileKind && $0.tier == tier }
        let wants4k = tier == .uhd
        let kindMatch = { (r: RootFolder) in rootMatchesKind(r.path, kind: kind) }
        let tierMatch = { (r: RootFolder) in rootIs4k(r.path) == wants4k }
        let root = roots.first { kindMatch($0) && tierMatch($0) } ?? roots.first(where: kindMatch)
            ?? roots.first(where: tierMatch) ?? roots.first
        let profileTier = { (p: QualityProfile) in profileIs4k(p) == wants4k }
        let animeProfile: QualityProfile? = isAnime
            ? profiles.first(where: { $0.mediaKind == "anime" && profileTier($0) }) : nil
        let profile = animeProfile ?? profiles.first(where: profileTier) ?? profiles.first
        return (slot?.rootFolderId ?? root?.id, slot?.qualityProfileId ?? profile?.id)
    }
}

/// One tier's edition card (`EditionConfig`): dot, label, tag, switch, then
/// the root folder and quality profile pickers.
struct ApproveEditionCard: View {
    let tier: QualityTier
    @Binding var config: ApproveTierConfig
    let roots: [RootFolder]
    let profiles: [QualityProfile]
    /// "default" on HD in the add flow; "requested" on the locked approve tier.
    var tag: String?
    var locked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(tier.color).frame(width: 9, height: 9)
                Text(tier.chipLabel).font(.system(size: 13.5, weight: .bold)).foregroundStyle(Theme.txt)
                if let tag {
                    Text(tag)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.done)
                        .padding(.horizontal, 7).padding(.vertical, 1)
                        .background(Theme.done.opacity(0.16), in: Capsule())
                }
                Spacer(minLength: 0)
                Toggle("", isOn: $config.enabled)
                    .labelsHidden()
                    .tint(Theme.indigo)
                    .disabled(locked)
                    .accessibilityLabel("Enable \(tier.chipLabel)")
            }
            pickerRow("Root folder", value: roots.first { $0.id == config.rootId }?.path, mono: true) {
                ForEach(roots) { root in Button(root.path) { config.rootId = root.id } }
            }
            pickerRow("Quality profile", value: profiles.first { $0.id == config.profileId }?.name, mono: false) {
                ForEach(profiles) { profile in Button(profile.name) { config.profileId = profile.id } }
            }
        }
        .padding(13)
        .panel(Theme.card, radius: 14)
        .opacity(config.enabled ? 1 : 0.72)
        .animation(.easeOut(duration: 0.18), value: config.enabled)
    }

    private func pickerRow<Items: View>(_ label: String, value: String?, mono: Bool, @ViewBuilder items: () -> Items) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12)).foregroundStyle(Theme.mut)
            Menu { items() } label: {
                HStack {
                    Text(value ?? "Choose…")
                        .font(.system(size: mono ? 12.5 : 13, weight: mono ? .regular : .semibold,
                                      design: mono ? .monospaced : .default))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.mut)
                }
                .foregroundStyle(Theme.txt)
                .padding(.horizontal, 11)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.line))
            }
        }
    }
}

/// A web-style checkbox square.
struct WebCheckSquare: View {
    let checked: Bool
    var color: Color = Theme.indigo
    var size: CGFloat = 20

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(checked ? color : .clear)
            .overlay(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .strokeBorder(checked ? color : Theme.line, lineWidth: 2))
            .overlay {
                if checked {
                    Image(systemName: "checkmark").font(.system(size: size * 0.55, weight: .heavy)).foregroundStyle(Theme.bg)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: size, height: size)
            .animation(.snappy(duration: 0.15), value: checked)
    }
}

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
                .overlay { DiscoverArt(url: TMDBImage.resized(preview?.posterUrl ?? pick.posterUrl, to: "w342")) }
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

// MARK: - Requests tab

struct RequestsPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(DiscoverStore.self) private var store
    let approver: Bool

    var body: some View {
        if approver { ApprovalQueue() } else { MyRequests() }
    }
}

private enum QueueFilter: String, CaseIterable, Hashable {
    case pending, approved, available, declined, all

    func matches(_ status: String) -> Bool {
        switch self {
        case .pending: return status == "pending"
        case .approved: return status == "approved"
        case .available: return status == "fulfilled"
        case .declined: return status == "rejected" || status == "deferred"
        case .all: return true
        }
    }

    var empty: String {
        switch self {
        case .pending: return "No pending requests."
        case .approved: return "No approved requests."
        case .available: return "No available requests."
        case .declined: return "No declined requests."
        case .all: return "No requests."
        }
    }

    var title: String {
        switch self {
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .available: return "Available"
        case .declined: return "Declined"
        case .all: return "All"
        }
    }
}

private struct ApprovalQueue: View {
    @Environment(DiscoverStore.self) private var store
    @State private var filter: QueueFilter = .pending
    @State private var approving: MediaRequest?
    @State private var rejecting: MediaRequest?

    var body: some View {
        let all = Array(store.requests.reversed())
        VStack(alignment: .leading, spacing: 16) {
            DiscoverSegmented(options: QueueFilter.allCases.map { f -> (QueueFilter, String) in
                let count = all.filter { f.matches($0.status) }.count
                return (f, f == .all || count == 0 ? f.title : "\(f.title) \(count)")
            }, selection: $filter, fullTrack: true)
            if !store.requestsLoaded {
                DiscoverEmptyState(message: "Loading requests…")
            } else if store.requestsFailed {
                DiscoverEmptyState(message: "Could not load requests.")
            } else {
                let rows = all.filter { filter.matches($0.status) }
                if rows.isEmpty {
                    DiscoverEmptyState(message: filter.empty)
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, request in
                            RequestRow(request: request, approverMeta: true) {
                                if request.status == "pending" {
                                    HStack(spacing: 6) {
                                        Button("Approve") { approving = request }.buttonStyle(.discover(.primary))
                                        Button("Reject") { rejecting = request }.buttonStyle(.discover(.subtle))
                                    }
                                } else {
                                    RequestStatusPill(label: request.status, color: RequestStatusStyle.color(request.status))
                                }
                            }
                            .discoverReveal(index: index)
                            .approverMenu(enabled: request.status == "pending",
                                          approve: { approving = request }, reject: { rejecting = request })
                        }
                    }
                }
            }
        }
        .sheet(item: $approving) { request in
            ApproveDialog(request: request) { store.requestsVersion += 1 }
        }
        .sheet(item: $rejecting) { request in
            RejectDialog(request: request) { store.requestsVersion += 1 }
        }
    }
}

private extension View {
    /// Rows are not in a List, so a long-press menu stands in for swipe actions.
    @ViewBuilder
    func approverMenu(enabled: Bool, approve: @escaping () -> Void, reject: @escaping () -> Void) -> some View {
        if enabled {
            contextMenu {
                Button(action: approve) { Label("Approve", systemImage: "checkmark") }
                Button(role: .destructive, action: reject) { Label("Reject", systemImage: "xmark") }
            }
        } else {
            self
        }
    }
}

private struct MyRequests: View {
    @Environment(AppModel.self) private var model
    @Environment(DiscoverStore.self) private var store
    @State private var reporting: MediaRequest?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !store.requestsLoaded {
                DiscoverEmptyState(message: "Loading your requests…")
            } else if store.requestsFailed {
                DiscoverEmptyState(message: "Could not load your requests.")
            } else if store.requests.isEmpty {
                DiscoverEmptyState(message: "You haven't requested anything yet.")
            } else {
                ForEach(Array(store.requests.enumerated()), id: \.element.id) { index, request in
                    RequestRow(request: request, approverMeta: false) {
                        if request.status == "pending" {
                            DiscoverIconButton(systemImage: "trash", label: "Withdraw request", tint: Theme.danger) {
                                Task { await withdraw(request) }
                            }
                        } else if request.status == "fulfilled", request.mediaItemId != nil {
                            Button("Report an issue") { reporting = request }.buttonStyle(.discover(.subtle))
                        }
                    }
                    .discoverReveal(index: index)
                }
            }
        }
        .sheet(item: $reporting) { request in
            if let id = request.mediaItemId {
                IssueModal(mediaItemId: id,
                           title: PreviewCache.shared.get(request.previewKind, request.tmdbId)?.title ?? "TMDB #\(request.tmdbId)",
                           isSeries: request.kind == .series, seasons: nil)
            }
        }
    }

    private func withdraw(_ request: MediaRequest) async {
        do {
            try await model.client?.withdrawRequest(id: request.id)
            store.requestsVersion += 1
        } catch {
            DiscoverToasts.shared.error("Could not withdraw request", error)
        }
    }
}

/// One request row: wash by status, 40pt poster, title, meta, note, actions.
private struct RequestRow<Actions: View>: View {
    @Environment(AppModel.self) private var model
    let request: MediaRequest
    let approverMeta: Bool
    @ViewBuilder var actions: Actions

    var body: some View {
        let preview = PreviewCache.shared.get(request.previewKind, request.tmdbId)
        let color = RequestStatusStyle.color(request.status)
        HStack(spacing: 14) {
            Color.clear
                .frame(width: 40, height: 60)
                .overlay { DiscoverArt(url: TMDBImage.resized(preview?.posterUrl, to: "w154")) }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.line))
            VStack(alignment: .leading, spacing: 0) {
                Text(preview?.title ?? "TMDB #\(request.tmdbId)")
                    .font(.system(size: 13.5, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(1)
                meta.padding(.top, 3)
                if let note = request.note, !note.isEmpty {
                    Text("“\(note)”").font(.system(size: 12)).italic().foregroundStyle(Theme.mut).lineLimit(1)
                        .padding(.top, 5)
                }
            }
            Spacer(minLength: 0)
            actions
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .statusWash(color)
        .task { await PreviewCache.shared.load(model.client, kind: request.previewKind, tmdbId: request.tmdbId) }
    }

    @ViewBuilder
    private var meta: some View {
        let tiers = request.tiers.map(\.chipLabel).joined(separator: " + ")
        if approverMeta {
            Text([request.kind == .movie ? "Movie" : "Series", tiers,
                  "Requested by user #\(request.userId ?? 0)", DiscoverRelativeTime.string(request.requestedAt)]
                .filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.system(size: 12)).foregroundStyle(Theme.mut)
        } else {
            PreviewFlow(spacing: 6) {
                RequestStatusPill(label: request.status, color: RequestStatusStyle.color(request.status))
                Text(tiers)
                Text("·")
                Text(DiscoverRelativeTime.string(request.requestedAt))
            }
            .font(.system(size: 12)).foregroundStyle(Theme.mut)
        }
    }
}

// MARK: - Approve / Reject

private struct ApproveDialog: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let request: MediaRequest
    let onDone: () -> Void

    @State private var roots: [RootFolder] = []
    @State private var profiles: [QualityProfile] = []
    @State private var hd = ApproveTierConfig(enabled: true)
    @State private var uhd = ApproveTierConfig(enabled: false)
    @State private var search = true
    @State private var loaded = false
    @State private var sending = false

    private var preview: MediaPreviewDetail? { PreviewCache.shared.get(request.previewKind, request.tmdbId) }
    private var isAnime: Bool { preview?.isAnime ?? false }
    private var enabledCount: Int { [hd, uhd].filter(\.enabled).count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "paperplane").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.grab)
                            .frame(width: 34, height: 34)
                            .background(Theme.grab.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Approve request").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
                            Text("Enable the editions to add — the requested tier is locked on.")
                                .font(.system(size: 13)).foregroundStyle(Theme.mut)
                        }
                    }
                    HStack(spacing: 12) {
                        Color.clear.frame(width: 52, height: 78)
                            .overlay { DiscoverArt(url: TMDBImage.resized(preview?.posterUrl, to: "w154")) }
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            (Text(preview?.title ?? "TMDB #\(request.tmdbId)").foregroundColor(Theme.txt)
                             + Text(preview?.year.map { " (\($0))" } ?? "").foregroundColor(Theme.dim))
                                .font(.system(size: 14, weight: .bold))
                            Text("Requested by user #\(request.userId ?? 0) · \(request.tier.chipLabel)")
                                .font(.system(size: 12)).foregroundStyle(Theme.mut)
                        }
                    }
                    .padding(.top, 14).padding(.bottom, 16)
                    if loaded {
                        VStack(spacing: 12) {
                            ApproveEditionCard(tier: .hd, config: $hd, roots: roots, profiles: profiles,
                                            tag: request.tier == .hd ? "requested" : nil, locked: request.tier == .hd)
                            ApproveEditionCard(tier: .uhd, config: $uhd, roots: roots, profiles: profiles,
                                            tag: request.tier == .uhd ? "requested" : nil, locked: request.tier == .uhd)
                            Toggle(isOn: $search) {
                                Text("Search & grab now").font(.system(size: 13)).foregroundStyle(Theme.txt)
                            }
                            .tint(Theme.indigo)
                            .padding(.top, 4)
                        }
                    } else {
                        Text("Loading defaults…").font(.system(size: 13)).foregroundStyle(Theme.mut)
                            .frame(maxWidth: .infinity).padding(.vertical, 20)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .background(Theme.panel)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(sending ? "Approving…" : (enabledCount == 2 ? "Approve · 2 editions" : "Approve")) {
                        Task { await approve() }
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.indigo)
                    .disabled(!loaded || sending || enabledCount == 0)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.panel)
        .task { await load() }
    }

    private func load() async {
        guard let client = model.client else { return }
        await PreviewCache.shared.load(client, kind: request.previewKind, tmdbId: request.tmdbId)
        async let r = client.rootFolders()
        async let p = client.qualityProfiles()
        async let d = client.addDefaults()
        roots = (try? await r) ?? []
        let allProfiles = (try? await p) ?? []
        let defaults = (try? await d) ?? []
        profiles = DiscoverEditionDefaults.profiles(allProfiles, kind: request.kind, isAnime: isAnime)
        for tier in [QualityTier.hd, .uhd] {
            let (root, profile) = DiscoverEditionDefaults.resolve(tier, kind: request.kind, isAnime: isAnime,
                                                          roots: roots, profiles: profiles, defaults: defaults)
            let enabled = tier == .hd ? true : false
            let config = ApproveTierConfig(enabled: enabled || tier == request.tier, rootId: root, profileId: profile)
            if tier == .hd { hd = config } else { uhd = config }
        }
        loaded = true
    }

    private func approve() async {
        guard let client = model.client else { return }
        sending = true
        defer { sending = false }
        let editions = [(QualityTier.hd, hd), (.uhd, uhd)].filter { $0.1.enabled }.map {
            ApproveEdition(tier: $0.0, rootFolderId: $0.1.rootId, qualityProfileId: $0.1.profileId)
        }
        do {
            try await client.approveRequest(id: request.id, body: ApproveBody(editions: editions, search: search))
            DiscoverToasts.shared.show(.success, "\(preview?.title ?? "TMDB #\(request.tmdbId)") approved")
            onDone()
            dismiss()
        } catch {
            DiscoverToasts.shared.error("Could not approve request", error)
        }
    }
}

private struct RejectDialog: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let request: MediaRequest
    let onDone: () -> Void
    @State private var reason: RequestReason = .other
    @State private var note = ""
    @State private var defer_ = false
    @State private var sending = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Reason", selection: $reason) {
                        ForEach(RequestReason.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    TextField("Note (optional)", text: $note, axis: .vertical).lineLimit(2...4)
                    Toggle("Defer instead of rejecting outright", isOn: $defer_).tint(Theme.indigo)
                } footer: {
                    Text("Choose a reason — or defer it as \"not available yet\" to keep it on the requester's list.")
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.panel)
            .navigationTitle("Reject request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(sending ? "Saving…" : (defer_ ? "Defer" : "Reject")) { Task { await submit() } }
                        .buttonStyle(.glassProminent)
                        .tint(Theme.danger)
                        .disabled(sending)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.panel)
    }

    private func submit() async {
        sending = true
        defer { sending = false }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await model.client?.rejectRequest(id: request.id, body: RejectBody(reason: reason, defer: defer_,
                                                                                note: trimmed.isEmpty ? nil : trimmed))
            DiscoverToasts.shared.show(.success, defer_ ? "Request deferred" : "Request rejected")
            onDone()
            dismiss()
        } catch {
            DiscoverToasts.shared.error("Could not decide request", error)
        }
    }
}

// MARK: - Add collection

/// The Add-collection modal: missing films preselected, one shared edition
/// config, then `POST /api/v1/collections/{id}/add`.
struct AddCollectionSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let summary: CollectionSummary
    let onDone: () -> Void

    @State private var detail: CollectionDetail?
    @State private var selected: Set<Int> = []
    @State private var roots: [RootFolder] = []
    @State private var profiles: [QualityProfile] = []
    @State private var hd = ApproveTierConfig(enabled: true)
    @State private var uhd = ApproveTierConfig(enabled: false)
    @State private var searchOnAdd = true
    @State private var failed = false
    @State private var sending = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let detail {
                        ForEach(detail.parts, id: \.tmdbId) { part in
                            let owned = part.inLibrary == true
                            Button {
                                if selected.contains(part.tmdbId) { selected.remove(part.tmdbId) } else { selected.insert(part.tmdbId) }
                            } label: {
                                HStack(spacing: 12) {
                                    if owned {
                                        PosterStatusBadge(kind: .inLibrary).scaleEffect(0.8).frame(width: 20, height: 20)
                                    } else {
                                        WebCheckSquare(checked: selected.contains(part.tmdbId))
                                    }
                                    Text(part.title ?? "TMDB #\(part.tmdbId)").font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(owned ? Theme.mut : Theme.txt)
                                    if let year = part.year { Text(verbatim: "\(year)").font(.system(size: 12)).foregroundStyle(Theme.dim) }
                                    Spacer(minLength: 0)
                                }
                                .padding(12)
                                .panel(Theme.card, radius: 11)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(owned)
                        }
                        DialogSectionLabel(text: "Editions").padding(.top, 8)
                        ApproveEditionCard(tier: .hd, config: $hd, roots: roots, profiles: profiles, tag: "default")
                        ApproveEditionCard(tier: .uhd, config: $uhd, roots: roots, profiles: profiles)
                        Toggle(isOn: $searchOnAdd) {
                            Text("Start search for missing on add").font(.system(size: 13)).foregroundStyle(Theme.txt)
                        }
                        .tint(Theme.indigo)
                    } else if failed {
                        DiscoverEmptyState(message: "Could not load this collection.")
                    } else {
                        Text("Loading…").font(.system(size: 13)).foregroundStyle(Theme.mut)
                            .frame(maxWidth: .infinity).padding(.vertical, 30)
                    }
                }
                .padding(16)
            }
            .background(Theme.panel)
            .navigationTitle(summary.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(sending ? "Adding…" : "Add \(selected.count) film\(selected.count == 1 ? "" : "s")") {
                        Task { await add() }
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.indigo)
                    .disabled(sending || selected.isEmpty || ![hd, uhd].contains { $0.enabled })
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.panel)
        .task { await load() }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            let loaded = try await client.collection(id: summary.collectionTmdbId)
            detail = loaded
            selected = Set(loaded.parts.filter { $0.inLibrary != true }.map(\.tmdbId))
        } catch {
            failed = true
            return
        }
        async let r = client.rootFolders()
        async let p = client.qualityProfiles()
        async let d = client.addDefaults()
        roots = (try? await r) ?? []
        profiles = DiscoverEditionDefaults.profiles((try? await p) ?? [], kind: .movie, isAnime: false)
        let defaults = (try? await d) ?? []
        let h = DiscoverEditionDefaults.resolve(.hd, kind: .movie, isAnime: false, roots: roots, profiles: profiles, defaults: defaults)
        let u = DiscoverEditionDefaults.resolve(.uhd, kind: .movie, isAnime: false, roots: roots, profiles: profiles, defaults: defaults)
        hd = ApproveTierConfig(enabled: true, rootId: h.0, profileId: h.1)
        uhd = ApproveTierConfig(enabled: false, rootId: u.0, profileId: u.1)
    }

    private func add() async {
        guard let client = model.client else { return }
        sending = true
        defer { sending = false }
        var editions: [EditionCreate] = []
        for (tier, config) in [(QualityTier.hd, hd), (.uhd, uhd)] where config.enabled {
            guard let root = config.rootId, let profile = config.profileId else { continue }
            editions.append(EditionCreate(tier: tier, rootFolderId: root, qualityProfileId: profile))
        }
        do {
            try await client.addCollection(id: summary.collectionTmdbId,
                                           body: CollectionAddBody(tmdbIds: selected.sorted(), editions: editions,
                                                                   searchOnAdd: searchOnAdd))
            DiscoverToasts.shared.show(.success, "Added \(selected.count) film\(selected.count == 1 ? "" : "s") from \(summary.name)")
            onDone()
            await model.loadLibrary()
            dismiss()
        } catch {
            DiscoverToasts.shared.error("Could not add collection", error)
        }
    }
}
