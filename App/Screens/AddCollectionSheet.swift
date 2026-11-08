import SwiftUI
import FusionhaKit

// MARK: - Add collection

/// The Add-collection modal: missing films preselected, one shared edition
/// config, then `POST /api/v1/collections/{id}/add`.
struct AddCollectionSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    /// v2 (S11): the art header, the films as posters, W1 cards.
    @Environment(\.browseLook) private var look
    let summary: CollectionSummary
    /// The films to preselect (the detail page's "Add all missing" or one film); nil = every missing film.
    var preselect: [Int]? = nil
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
                    if let detail, look != nil {
                        v2Films(detail)
                        #if V2
                        // Look Pass family 1: each edition one form card, native pickers.
                        V2FormLabel(text: "Editions").padding(.top, 8)
                        V2CollectionEditionCard(tier: .hd, config: $hd, roots: roots, profiles: profiles, tag: "default")
                        V2CollectionEditionCard(tier: .uhd, config: $uhd, roots: roots, profiles: profiles)
                        V2CollectionSearchToggle(isOn: $searchOnAdd)
                        #else
                        DialogSectionLabel(text: "Add them as").padding(.top, 8)
                        VStack(alignment: .leading, spacing: 12) { editions }
                            .padding(12)
                            .browseCard(look, radius: 20)
                        #endif
                    } else if let detail {
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
                                .cardSurface(radius: 11, lift: false)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(owned)
                        }
                        DialogSectionLabel(text: "Editions").padding(.top, 8)
                        editions
                    } else if failed {
                        DiscoverEmptyState(message: "Could not load this collection.")
                    } else {
                        Text("Loading…").font(.system(size: 13)).foregroundStyle(Theme.mut)
                            .frame(maxWidth: .infinity).padding(.vertical, 30)
                    }
                }
                .padding(16)
            }
            .background(look == nil ? Theme.panel : .clear)
            .browseGround(look, backdrop: summary.backdropUrl, poster: summary.posterUrl)
            .navigationTitle(look == nil ? summary.name : "Complete the collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    ToolbarActionButton(title: sending ? "Adding…" : "Add \(selected.count) film\(selected.count == 1 ? "" : "s")",
                                        systemImage: "plus", busy: sending) {
                        Task { await add() }
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.indigo)
                    .disabled(selected.isEmpty || ![hd, uhd].contains { $0.enabled })
                }
            }
        }
        .presentationDragIndicator(.visible)
        .sheetBackground(Theme.panel)
        .task { await load() }
    }

    @ViewBuilder
    private var editions: some View {
        ApproveEditionCard(tier: .hd, config: $hd, roots: roots, profiles: profiles, tag: "default")
        ApproveEditionCard(tier: .uhd, config: $uhd, roots: roots, profiles: profiles)
        Toggle(isOn: $searchOnAdd) {
            Text("Start search for missing on add").font(.system(size: 13)).foregroundStyle(Theme.txt)
        }
        .tint(Theme.indigo)
    }

    /// v2: the art header, select all / none, the films as posters.
    @ViewBuilder
    private func v2Films(_ detail: CollectionDetail) -> some View {
        let missing = detail.parts.filter { $0.owned != true }.map(\.tmdbId)
        #if V2
        V2SheetHeading(title: detail.name,
                       subtitle: "\(detail.totalCount) films · \(detail.ownedCount) in your library · \(missing.count) to add")
        #else
        CollectionSheetHeader(name: detail.name, backdrop: summary.backdropUrl ?? detail.posterUrl,
                              total: detail.totalCount, owned: detail.ownedCount, missing: missing.count)
        #endif
        HStack(spacing: 8) {
            Button("Select all missing") { selected = Set(missing) }
                .buttonStyle(.glass)
            Button("Deselect all") { selected = [] }
                .buttonStyle(.glass)
                .disabled(selected.isEmpty)
        }
        .font(.system(size: 13, weight: .semibold))
        .padding(.top, 2)
        CollectionPartGrid(parts: detail.parts, selected: $selected)
            .padding(.top, 2)
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            let loaded = try await client.collection(id: summary.collectionTmdbId)
            detail = loaded
            let missing = Set(loaded.parts.filter { $0.inLibrary != true }.map(\.tmdbId))
            selected = preselect.map { missing.intersection($0) } ?? missing
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
