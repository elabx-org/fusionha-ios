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
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.mut)
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
        if approver { ApproverRequestsView() } else { MineView() }
    }
}
