import SwiftUI
import FusionhaKit

/// The History tab's Lifecycle view: one lane per version in scope, its
/// events oldest first along one line (the glyphs of the timeline), then
/// whether the version holds a file now. A W1 module per lane.
struct V2HistoryLifecycle: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.pagePalette) private var page
    @Environment(\.badgeInk) private var inkOverride
    let detail: ItemDetail
    let entries: [HistoryEntry]

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(store.scopedEditions) { edition in
                lane(edition)
            }
        }
    }

    private func lane(_ edition: DetailEdition) -> some View {
        let events = entries.filter { $0.editionId == edition.id }.sorted { $0.createdAt < $1.createdAt }
        let hasFile = detail.fileCount(edition) > 0
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                EditionBadge(tier: edition.tier, state: hasFile ? .onDisk : .missing, showsCount: false)
                Text(detail.versionName(edition))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text("\(events.count) event\(events.count == 1 ? "" : "s")")
                    .font(.system(size: 12.5))
                    .foregroundStyle(muted)
            }
            if events.isEmpty {
                Text("No events for this version.").font(.system(size: 13)).foregroundStyle(muted)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(events) { entry in
                            node(entry)
                            if entry.id != events.last?.id {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(muted)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
            if !hasFile {
                Text("No current file").font(.system(size: 12.5, weight: .medium)).foregroundStyle(muted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { ModuleSurface(radius: 18) }
    }

    private func node(_ entry: HistoryEntry) -> some View {
        let look = V2EpisodeHistoryStrip.look(entry.eventType, ink: inkOverride ?? .page)
        return HStack(spacing: 6) {
            Image(systemName: look.icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(look.onFill)
                .frame(width: 18, height: 18)
                .background(look.fill, in: Circle())
            VStack(alignment: .leading, spacing: 0) {
                Text(eventStyle(entry.eventType).label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ink)
                Text(DetailText.relative(entry.createdAt))
                    .font(.system(size: 11))
                    .foregroundStyle(muted)
            }
            .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}
