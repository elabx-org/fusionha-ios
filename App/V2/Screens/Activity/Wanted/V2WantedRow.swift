import SwiftUI
import FusionhaKit

/// A wanted title as a row of the Wanted module (mock activity-log.js
/// `wRow`): poster, title, the one fact that explains why it is wanted, one
/// T5 ticket per version with its state in words, and the round search
/// menu. A gradual search's progress strip shows under it while it runs.
struct V2WantedRow: View {
    let item: WantedItem
    let tab: WantedTab
    let interval: Int
    var searchHighlighted = false
    @Environment(\.pagePalette) private var page
    @Environment(\.motionEnabled) private var motion
    @State private var search = V2WantedSearch()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 11) {
                V2ScopeThumb(url: item.posterUrl)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(page?.ink ?? Theme.txt)
                        .lineLimit(1)
                    if let head = WantedLogic.primaryEdition(item, tab) {
                        Text(WantedLogic.cue(item, head)).font(.system(size: 12.5)).foregroundStyle(page?.inkMuted ?? Theme.mut)
                            .lineLimit(2)
                    }
                    V2WantedTickets(item: item).padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                V2WantedSearchMenu(item: item, tab: tab, search: search, highlighted: searchHighlighted)
            }
            if let run = search.gradualRun {
                WantedGradualStrip(itemId: item.id, runId: run, fallbackTotal: search.gradualTotal, interval: interval) {
                    withAnimation(motion ? .easeOut(duration: 0.2) : nil) { search.gradualRun = nil }
                }
                .transition(.opacity)
            }
        }
    }
}

/// One T5 ticket per wanted version with its state in words ("4K · 10
/// missing", "HD below cutoff").
struct V2WantedTickets: View {
    let item: WantedItem
    @Environment(\.pagePalette) private var page

    var body: some View {
        ActFlow(spacing: 8, lineSpacing: 5) {
            ForEach(item.editions) { edition in
                HStack(spacing: 5) {
                    EditionBadge(tier: edition.tier, state: V2WantedEditionCopy.badge(edition), showsCount: false)
                    Text(V2WantedEditionCopy.words(edition))
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(page?.inkMuted ?? Theme.mut)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// A title seen in 4K that you only have in HD (mock `w4Row`): the HD
/// ticket on disk and Add 4K version, in place of v1's coverage rails.
struct V2FourKRow: View {
    let item: FourKAvailableItem
    let add: () -> Void
    @Environment(\.pagePalette) private var page

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            V2ScopeThumb(url: item.posterUrl)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(page?.ink ?? Theme.txt)
                    .lineLimit(1)
                Text(V2FourKCopy.seen(item)).font(.system(size: 12.5)).foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        EditionBadge(tier: .hd, state: .onDisk, showsCount: false)
                        Text(V2FourKCopy.owned(item)).font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    }
                    V2CapsuleButton(title: "Add 4K version", systemImage: "plus", action: add)
                }
                .padding(.top, 5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The 4K rows' words.
enum V2FourKCopy {
    /// "Seen in 4K 247 times · WEB-DL 2160p · 7.1 GB · last seen 2 Nov".
    static func seen(_ item: FourKAvailableItem) -> String {
        var parts = [item.seenCount == 1 ? "Seen in 4K once" : "Seen in 4K \(item.seenCount) times"]
        if let quality = item.bestQuality { parts.append(ActFmt.quality(quality)) }
        if let size = item.bestSize, size > 0 { parts.append(ActFmt.bytes(size)) }
        if let last = item.lastSeenAt { parts.append("last seen \(ActFmt.relative(last))") }
        return parts.joined(separator: " · ")
    }

    /// "HD on disk", or the seasons it covers ("HD 3 of 4 seasons").
    static func owned(_ item: FourKAvailableItem) -> String {
        guard let total = item.totalSeasons, total > 0 else { return "HD on disk" }
        return "HD \(item.hdOwnedSeasons ?? 0) of \(total) season\(total == 1 ? "" : "s")"
    }
}
