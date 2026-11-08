import SwiftUI
import FusionhaKit

/// v2's Approve with changes (mock requests.js `approveSheet`): one grouped
/// Form. What was asked on top, the versions as switches (an asked version
/// stays on), where each goes (root folder, quality profile), Monitor and
/// Search when approved, then the cost sentence saying what Approve will do
/// as it stands. The same approve call as v1's `ApproveDialog`. The mock's
/// "Note to eafx" row is left out: the approve call takes no note.
struct V2ApproveSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let request: MediaRequest
    let triage: RequestTriage?
    let onDone: () -> Void

    @State private var roots: [RootFolder] = []
    @State private var profiles: [QualityProfile] = []
    @State private var hd = ApproveTierConfig(enabled: true)
    @State private var uhd = ApproveTierConfig(enabled: false)
    @State private var monitor = true
    @State private var search = true
    @State private var loaded = false
    @State private var sending = false

    private var preview: MediaPreviewDetail? { PreviewCache.shared.get(request.previewKind, request.tmdbId) }
    private var title: String { request.title ?? preview?.title ?? "TMDB #\(request.tmdbId)" }
    private var requester: String { TriageFacts.requesterName(request) }
    private var chosen: [QualityTier] { [(QualityTier.hd, hd), (.uhd, uhd)].filter { $0.1.enabled }.map { $0.0 } }

    var body: some View {
        NavigationStack {
            Form {
                if loaded {
                    V2ApproveVersionsSection(request: request, triage: triage, profiles: profiles,
                                             asked: ApproveCost.askedLine(requester: requester, asked: request.tiers),
                                             hd: $hd, uhd: $uhd)
                    V2ApprovePlaceSection(hd: $hd, uhd: $uhd, roots: roots, profiles: profiles,
                                          monitor: $monitor, search: $search,
                                          cost: ApproveCost.sentence(title: title, tiers: chosen, triage: triage,
                                                                     search: search, requester: requester))
                } else {
                    Section { Text("Loading defaults…").foregroundStyle(Theme.mut) }
                        .listRowBackground(AccountStyle.cell)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Approve \(title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    ToolbarActionButton(title: sending ? "Approving…" : "Approve", systemImage: "checkmark", busy: sending) {
                        Task { await approve() }
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.primary)
                    .disabled(!loaded || chosen.isEmpty || sending)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .task { await load() }
    }

    /// v1's defaults: the Add-defaults root and profile per version; the
    /// asked versions start on.
    private func load() async {
        guard let client = model.client else { return }
        await PreviewCache.shared.load(client, kind: request.previewKind, tmdbId: request.tmdbId)
        async let r = client.rootFolders()
        async let p = client.qualityProfiles()
        async let d = client.addDefaults()
        roots = (try? await r) ?? []
        let allProfiles = (try? await p) ?? []
        let defaults = (try? await d) ?? []
        let isAnime = triage?.isAnime ?? preview?.isAnime ?? false
        profiles = DiscoverEditionDefaults.profiles(allProfiles, kind: request.kind, isAnime: isAnime)
        for tier in [QualityTier.hd, .uhd] {
            let (root, profile) = DiscoverEditionDefaults.resolve(tier, kind: request.kind, isAnime: isAnime,
                                                                  roots: roots, profiles: profiles, defaults: defaults)
            let on = tier == .hd || request.tiers.contains(tier)
            let config = ApproveTierConfig(enabled: on, rootId: root, profileId: profile)
            if tier == .hd { hd = config } else { uhd = config }
        }
        loaded = true
    }

    private func approve() async {
        guard let client = model.client else { return }
        sending = true
        defer { sending = false }
        let editions = [(QualityTier.hd, hd), (.uhd, uhd)].filter { $0.1.enabled }.map {
            ApproveEdition(tier: $0.0, rootFolderId: $0.1.rootId, qualityProfileId: $0.1.profileId, monitored: monitor)
        }
        do {
            try await client.approveRequest(id: request.id, body: ApproveBody(editions: editions, search: search))
            DiscoverToasts.shared.show(.success, "\(title) approved")
            onDone()
            dismiss()
        } catch {
            DiscoverToasts.shared.error("Could not approve request", error)
        }
    }
}
