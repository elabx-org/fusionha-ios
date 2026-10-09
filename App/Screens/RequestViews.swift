import SwiftUI
import FusionhaKit

// Requests: the Requests tab (approval queue for approvers, "My requests" for
// everyone else) and the pieces the request sheets share (`components/discover/*`).
// The RequestModal, the Approve / Reject dialogs and the Add-collection sheet
// live in their own files.

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
