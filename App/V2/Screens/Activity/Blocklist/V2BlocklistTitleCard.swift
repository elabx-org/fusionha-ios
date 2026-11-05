import SwiftUI
import FusionhaKit

/// One title's blocked releases as a W1 card (mock `bCards` `.lg-tc`): the
/// poster, title and a one-line summary; open, its releases under it. On
/// the open Duo the card stays closed and a tap fills the right page
/// (`BlocklistTitlePane`).
struct V2BlocklistTitleCard: View {
    let group: BlocklistGrouping.Title
    let open: Bool
    /// The open Duo: a chevron that points at the right page.
    var points = false
    var selected = false
    let toggle: () -> Void
    let row: (BlocklistGrouping.Release) -> AnyView
    @Environment(\.pagePalette) private var page

    var body: some View {
        let releases = group.releases
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
                HStack(spacing: 11) {
                    V2ScopeThumb(url: group.entries.first?.posterUrl, width: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(group.entries.first?.itemTitle ?? "Unknown title").font(.system(size: 15, weight: .bold))
                            .foregroundStyle(page?.ink ?? Theme.txt).lineLimit(1)
                        Text(V2BlocklistCopy.summary(group)).font(.system(size: 12.5))
                            .foregroundStyle(page?.inkMuted ?? Theme.mut).lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: points ? "chevron.right" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(page?.inkMuted ?? Theme.mut)
                        .rotationEffect(.degrees(!points && open ? 180 : 0))
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(points ? "Shows its releases beside the list" : (open ? "Hides its releases" : "Shows its releases"))
            if open && !points {
                ModuleRows { ForEach(releases) { row($0) } }
            }
        }
        .padding(.horizontal, ModuleMetrics.inset)
        .padding(.vertical, 2)
        .background { ModuleSurface(selected: selected) }
    }
}

/// A title's blocked releases on the open Duo's right page (mock
/// `blockSplit`): the title, how many and which versions, Search again,
/// then every release on one card.
struct BlocklistTitlePane: View {
    let group: BlocklistGrouping.Title
    let row: (BlocklistGrouping.Release) -> AnyView
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.pagePalette) private var page

    var body: some View {
        let lead = group.entries[0]
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                V2ScopeThumb(url: lead.posterUrl, width: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(lead.itemTitle ?? "Unknown title").font(.system(size: 22, weight: .bold))
                        .foregroundStyle(page?.ink ?? Theme.txt)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(V2BlocklistCopy.paneSummary(group)).font(.system(size: 13))
                        .foregroundStyle(page?.inkMuted ?? Theme.mut)
                }
                Spacer(minLength: 8)
                if let id = lead.mediaItemId {
                    V2CapsuleButton(title: "Search again", systemImage: "magnifyingglass") {
                        Task {
                            await ActActions.search(model.client, toaster, itemId: id,
                                                    message: "Searching again for \(lead.itemTitle ?? lead.title)")
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                ModuleRows {
                    ForEach(group.releases) { release in row(release) }
                }
            }
            .padding(.horizontal, ModuleMetrics.inset)
            .padding(.vertical, 2)
            .background { ModuleSurface() }
        }
    }
}

/// The blocklist's summary lines.
enum V2BlocklistCopy {
    /// "13 releases · S1 · 2 days ago" from what the rows share.
    static func summary(_ group: BlocklistGrouping.Title) -> String {
        var parts = ["\(group.entries.count) release\(group.entries.count == 1 ? "" : "s")"]
        let seasons = Set(group.entries.compactMap { season($0.episodeLabel) }).sorted()
        if !seasons.isEmpty, seasons.count <= 3 { parts.append(seasons.map { "S\($0)" }.joined(separator: ", ")) }
        let recoverable = group.entries.filter { BlocklistCategory(reason: $0.reason) == .recoverable }.count
        if recoverable == group.entries.count { parts.append("can retry") }
        if let newest = group.entries.compactMap({ ActFmt.date($0.createdAt) }).max() { parts.append(ActFmt.relative(newest)) }
        return parts.joined(separator: " · ")
    }

    /// "13 blocked releases · HD and 4K".
    static func paneSummary(_ group: BlocklistGrouping.Title) -> String {
        let tiers = Set(group.entries.compactMap(\.tier))
        let versions = [QualityTier.hd, .uhd].filter { tiers.contains($0) }.map(\.badgeLetters).joined(separator: " and ")
        let count = "\(group.entries.count) blocked release\(group.entries.count == 1 ? "" : "s")"
        return versions.isEmpty ? count : "\(count) · \(versions)"
    }

    /// The season number in "S02E03 · Name" or "S2 E3".
    private static func season(_ label: String?) -> Int? {
        guard let label, let r = label.range(of: #"S(\d+)"#, options: [.regularExpression, .caseInsensitive]) else { return nil }
        return Int(label[r].dropFirst())
    }
}
