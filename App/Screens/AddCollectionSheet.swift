import SwiftUI
import FusionhaKit

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
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await add() }
                    } label: {
                        ToolbarActionLabel(title: sending ? "Adding…" : "Add \(selected.count) film\(selected.count == 1 ? "" : "s")",
                                           systemImage: "plus")
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
