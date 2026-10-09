import SwiftUI
import FusionhaKit

// MARK: - Approve / Reject

struct ApproveDialog: View {
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
                             + Text(verbatim: preview?.year.map { " (\($0))" } ?? "").foregroundColor(Theme.dim))
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
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await approve() }
                    } label: {
                        ToolbarActionLabel(title: sending ? "Approving…" : (enabledCount == 2 ? "Approve · 2 editions" : "Approve"),
                                           systemImage: "checkmark")
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

struct RejectDialog: View {
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
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await submit() } } label: {
                        ToolbarActionLabel(title: sending ? "Saving…" : (defer_ ? "Defer" : "Reject"),
                                           systemImage: defer_ ? "clock" : "xmark.circle")
                    }
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
