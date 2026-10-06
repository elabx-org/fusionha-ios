import Foundation
import WidgetKit
import FusionhaKit

enum WidgetLoader {
    /// Look far enough ahead to find a few upcoming titles in a quiet week.
    static let upNextDays = 30

    /// The queue, and when idle a little of Up next and Recently added. Never
    /// throws: a failed queue read is the `failed` entry.
    static func downloads(_ client: APIClient, limit: Int, idleUpNext: Int, idleRecent: Int,
                          deadline: WidgetDeadline = WidgetDeadline(seconds: WidgetRun.budget)) async -> DownloadsEntry {
        guard var entry = try? await queue(client, limit: limit, deadline: deadline) else {
            return DownloadsEntry(date: .now, total: 0, rows: [], signedIn: true, failed: true)
        }
        if entry.idle {
            async let next = try? upNext(client, limit: idleUpNext, posterSize: "w92", deadline: deadline)
            async let latest = try? recent(client, limit: idleRecent, posterSize: "w154", deadline: deadline)
            entry.upNext = await next ?? []
            entry.recent = await latest ?? []
        }
        return entry
    }

    /// The download rows with their posters.
    static func queue(_ client: APIClient, limit: Int, deadline: WidgetDeadline) async throws -> DownloadsEntry {
        let page = try await withTimeout(seconds: deadline.slice(4, reserve: 3)) { try await client.queue(pageSize: limit) }
        let items = Array(page.items.prefix(limit))
        let posters = await fetchPosters(items.map(\.posterUrl), size: "w92", deadline: deadline)
        let rows = zip(items, posters).map { item, poster in
            DownloadsEntry.Row(
                itemId: item.mediaItemId,
                title: item.episodeLabel.map { "\(item.title) · \($0)" } ?? item.title,
                tier: item.tier, fraction: item.fraction, stalled: item.stalled, poster: poster,
                timeLeft: item.phase == "importing" ? "Importing"
                    : WidgetFeeds.timeLeft(fraction: item.fraction, ageSeconds: item.ageSeconds, stalled: item.stalled),
                size: item.size,
                rate: WidgetDownloadStats.rate(size: item.size, sizeleft: item.sizeleft, ageSeconds: item.ageSeconds,
                                               stalled: item.stalled))
        }
        return DownloadsEntry(date: .now, total: page.total, rows: rows, signedIn: true, failed: false)
    }

    static func upNext(_ client: APIClient, limit: Int, posterSize: String,
                       deadline: WidgetDeadline = WidgetDeadline(seconds: WidgetRun.budget)) async throws -> [UpNextRow] {
        try await upNextFeed(client, limit: limit, posterSize: posterSize, deadline: deadline).rows
    }

    /// The next `limit` items with posters, and how many air within seven days.
    static func upNextFeed(_ client: APIClient, limit: Int, posterSize: String,
                           deadline: WidgetDeadline = WidgetDeadline(seconds: WidgetRun.budget)) async throws
        -> (rows: [UpNextRow], week: Int) {
        let now = Date()
        let entries = try await withTimeout(seconds: deadline.slice(5, reserve: 1.5)) {
            try await client.calendar(start: now, end: CalendarMath.addDays(now, upNextDays))
        }
        let all = WidgetFeeds.upNext(entries, now: now, limit: 100)
        let week = all.filter { $0.airDate < CalendarMath.addDays(now, 7) }.count
        let items = Array(all.prefix(limit))
        let posters = await fetchPosters(items.map(\.posterUrl), size: posterSize, deadline: deadline)
        return (zip(items, posters).map { UpNextRow(item: $0, poster: $1) }, week)
    }

    static func recent(_ client: APIClient, limit: Int, posterSize: String,
                       deadline: WidgetDeadline = WidgetDeadline(seconds: WidgetRun.budget)) async throws -> [RecentImportRow] {
        let page = try await withTimeout(seconds: deadline.slice(5, reserve: 1.5)) { try await client.recentImports(pageSize: 40) }
        let items = WidgetFeeds.recentImports(page.items, limit: limit)
        let posters = await fetchPosters(items.map(\.posterUrl), size: posterSize, deadline: deadline)
        return zip(items, posters).map { RecentImportRow(item: $0, poster: $1) }
    }

    /// Small TMDB posters (w92/w154), three at a time, in input order. A slow
    /// or oversized poster is dropped (the row shows the plain placeholder).
    static func fetchPosters(_ urls: [String?], size: String,
                             deadline: WidgetDeadline = WidgetDeadline(seconds: WidgetRun.budget)) async -> [Data?] {
        let limit = deadline.slice(3, reserve: 0.5)
        return await concurrentMap(urls, maxConcurrent: 3) { raw -> Data? in
            guard let url = TMDBImage.resized(raw, to: size) else { return nil }
            let request = URLRequest(url: url, timeoutInterval: limit)
            let data = try? await withTimeout(seconds: limit) { try await URLSession.shared.data(for: request).0 }
            return data.flatMap(WidgetPosterData.small)
        }
    }

    /// Refresh after `idleMinutes`, or just after the next item airs if sooner.
    static func nextRefresh(idleMinutes: Double, nextAir: Date?) -> Date {
        let idle = Date.now.addingTimeInterval(idleMinutes * 60)
        guard let nextAir, nextAir > .now else { return idle }
        return min(idle, nextAir.addingTimeInterval(60))
    }
}
