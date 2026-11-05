import SwiftUI
import FusionhaKit

/// The Details tab's history strip (mock kit `history`): the shown
/// version's last four events for this episode, oldest first along one
/// line (v1's `EpisodeHistory` rows, season packs included). Grabs draw in
/// the accent, imports in the label ink, holds in orange, failures red.
struct V2EpisodeHistoryStrip: View {
    @Environment(\.pagePalette) private var page
    @Environment(\.badgeInk) private var inkOverride
    let detail: ItemDetail
    let episode: Episode
    let seasonNumber: Int
    let version: DetailEdition

    var body: some View {
        let all = EpisodeHistory.rows(detail.history ?? [], episodeId: episode.id, seasonNumber: seasonNumber,
                                      versionIds: [version.id])
        let shown = Array(all.prefix(4).reversed())
        if !shown.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                V2TitleSectionHead(title: "History",
                                   detail: "\(version.tier.badgeLetters) · \(all.count) event\(all.count == 1 ? "" : "s")",
                                   top: 0)
                ZStack(alignment: .top) {
                    Rectangle()
                        .fill((page?.ink ?? Theme.txt).opacity(0.16))
                        .frame(height: 2)
                        .padding(.horizontal, 24)
                        .padding(.top, 11)
                        .accessibilityHidden(true)
                    HStack(alignment: .top, spacing: 4) {
                        ForEach(shown) { entry in node(entry) }
                    }
                }
            }
        }
    }

    private func node(_ entry: HistoryEntry) -> some View {
        let ink = inkOverride ?? .page
        let look = Self.look(entry.eventType, ink: ink)
        return VStack(spacing: 6) {
            Image(systemName: look.icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(look.onFill)
                .frame(width: 24, height: 24)
                .background(look.fill, in: Circle())
                .background { Circle().fill(page?.tint ?? Theme.bg).padding(-3) }
            Text(eventStyle(entry.eventType).label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(page?.ink ?? Theme.txt)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(Self.when(entry.createdAt))
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(page?.inkMuted ?? Theme.mut)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    static func look(_ type: String, ink: BadgeInk) -> (icon: String, fill: Color, onFill: Color) {
        switch type {
        case "GRABBED": return ("arrow.down", ink.accent, Color.white)
        case "IMPORTED": return ("checkmark", ink.fill, ink.knockout)
        case "HELD", "NEEDS_ATTENTION", "GRAB_FAILED": return ("pause.fill", ink.held, Color.white)
        case "DOWNLOAD_FAILED", "FILE_MOVE_FAILED": return ("xmark", Theme.danger, Color.white)
        case "DELETED": return ("trash", Theme.danger, Color.white)
        default: return ("circle.fill", ink.secondary, ink.knockout)
        }
    }

    /// "21 Oct · 01:18".
    static func when(_ createdAt: String) -> String {
        guard let date = DetailText.instant(createdAt) else { return "" }
        return "\(date.formatted(.dateTime.day().month(.abbreviated))) · \(date.formatted(.dateTime.hour().minute()))"
    }
}

/// The History tab: the shown version's events for this episode as v1's
/// timeline rows, with the version switch.
struct V2EpisodeHistoryPane: View {
    @Environment(\.pagePalette) private var page
    let detail: ItemDetail
    let episode: Episode
    let seasonNumber: Int
    let version: DetailEdition?
    @Binding var versionId: Int

    var body: some View {
        let ids: Set<Int>? = version.map { [$0.id] }
        let rows = EpisodeHistory.rows(detail.history ?? [], episodeId: episode.id, seasonNumber: seasonNumber, versionIds: ids)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(rows.count) event\(rows.count == 1 ? "" : "s") · newest first")
                    .font(.system(size: 13))
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                Spacer(minLength: 8)
                V2EpisodeVersionPicker(editions: detail.orderedEditions, selection: $versionId)
            }
            if rows.isEmpty {
                Text("No history yet for this episode.")
                    .font(.system(size: 14))
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background { ModuleSurface(radius: 18) }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { TimelineRow(detail: detail, entry: $0) }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background { ModuleSurface(radius: 20) }
            }
        }
    }
}
