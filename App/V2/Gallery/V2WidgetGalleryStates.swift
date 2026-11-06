import Foundation
import FusionhaKit

/// Staged queue states for the v2 widget gallery, on the mock queue's real
/// titles: both versions of one title moving, one moving beside a hold, and
/// one episode alone. Needs you holds the first two titles.
enum V2WidgetGalleryStates {
    typealias State = DownloadsActivityAttributes.ContentState

    static func make(items: [QueueItem], thumbs: [String: Data]) -> [State] {
        let a = pick(items, 0, fallback: (1, "Wicked: For Good", nil))
        let b = pick(items, 1, fallback: (2, "VisionQuest", "S01E07 · Immolation"))
        let c = pick(items, 2, fallback: (3, "The Bear", "S04E02 · Grilled"))
        let both = state(rows: [row(a, 1, "HD", 0.41), row(a, 2, "4K", 0.03)], held: [], downloading: 2, needYou: 2,
                         thumbs: thumbs)
        let held = state(rows: [row(b, 3, "HD", 0.62)],
                         held: [State.Held(mediaItemId: b.id, title: b.title, count: 1, reason: "not really 2160p",
                                           downloadIds: [4], version: "4K")],
                         downloading: 1, needYou: 1, thumbs: thumbs)
        let single = state(rows: [row(c, 5, "4K", 0.88)], held: [], downloading: 1, needYou: 0, thumbs: thumbs)
        return [both, held, single]
    }

    static func needs(items: [QueueItem], posters: [Data?]) -> NeedsYouEntry {
        let reasons = ["not really 2160p", "splits an episode pair"]
        let rows = zip(items.prefix(2), reasons).enumerated().map { i, pair in
            let (item, reason) = pair
            let line = WidgetNeedsYou.Line(downloadId: item.id, mediaItemId: item.mediaItemId,
                                           short: "\(item.title) \(item.tier.badgeLetters)", title: item.title,
                                           detail: reason, tier: item.tier, posterUrl: item.posterUrl)
            return NeedsYouEntry.Row(line: line, poster: i < posters.count ? posters[i] : nil)
        }
        guard !rows.isEmpty else { return .placeholder }
        return NeedsYouEntry(date: .now, needCount: rows.count, rows: rows, movingCount: max(0, items.count - rows.count))
    }

    private typealias Title = (id: Int, title: String, sub: String?)

    private static func pick(_ items: [QueueItem], _ i: Int, fallback: Title) -> Title {
        guard i < items.count else { return fallback }
        return (items[i].mediaItemId, items[i].title, items[i].episodeLabel)
    }

    private static func row(_ t: Title, _ id: Int, _ version: String, _ fraction: Double) -> State.Row {
        State.Row(downloadId: id, mediaItemId: t.id, title: t.title, sub: t.sub, version: version, fraction: fraction,
                  posterUrl: nil)
    }

    private static func state(rows: [State.Row], held: [State.Held], downloading: Int, needYou: Int,
                              thumbs: [String: Data]) -> State {
        State(mode: .downloading, downloading: downloading, needYou: needYou, bps: 24_100_000, etaSeconds: 480,
              rows: rows, held: held, steps: nil, event: nil, updatedAt: Date().timeIntervalSince1970, thumbs: thumbs)
    }
}
