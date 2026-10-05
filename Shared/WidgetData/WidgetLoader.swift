import Foundation
import WidgetKit
import FusionhaKit

enum WidgetLoader {
    /// Look far enough ahead to find a few upcoming titles in a quiet week.
    static let upNextDays = 30

    static func downloads(_ client: APIClient, limit: Int, idleUpNext: Int, idleRecent: Int) async -> DownloadsEntry {
        do {
            let page = try await client.queue(pageSize: limit)
            let items = Array(page.items.prefix(limit))
            let posters = await fetchPosters(items.map(\.posterUrl), size: "w92")
            let rows = zip(items, posters).map { item, poster in
                DownloadsEntry.Row(
                    itemId: item.mediaItemId,
                    title: item.episodeLabel.map { "\(item.title) · \($0)" } ?? item.title,
                    tier: item.tier, fraction: item.fraction, stalled: item.stalled, poster: poster,
                    timeLeft: item.phase == "importing" ? "Importing"
                        : WidgetFeeds.timeLeft(fraction: item.fraction, ageSeconds: item.ageSeconds, stalled: item.stalled))
            }
            var entry = DownloadsEntry(date: .now, total: page.total, rows: rows, signedIn: true, failed: false)
            if entry.idle {
                async let next = try? upNext(client, limit: idleUpNext, posterSize: "w92")
                async let latest = try? recent(client, limit: idleRecent, posterSize: "w154")
                entry.upNext = await next ?? []
                entry.recent = await latest ?? []
            }
            return entry
        } catch {
            return DownloadsEntry(date: .now, total: 0, rows: [], signedIn: true, failed: true)
        }
    }

    static func upNext(_ client: APIClient, limit: Int, posterSize: String) async throws -> [UpNextRow] {
        let now = Date()
        let entries = try await client.calendar(start: now, end: CalendarMath.addDays(now, upNextDays))
        let items = WidgetFeeds.upNext(entries, now: now, limit: limit)
        let posters = await fetchPosters(items.map(\.posterUrl), size: posterSize)
        return zip(items, posters).map { UpNextRow(item: $0, poster: $1) }
    }

    static func recent(_ client: APIClient, limit: Int, posterSize: String) async throws -> [RecentImportRow] {
        let page = try await client.recentImports(pageSize: 40)
        let items = WidgetFeeds.recentImports(page.items, limit: limit)
        let posters = await fetchPosters(items.map(\.posterUrl), size: posterSize)
        return zip(items, posters).map { RecentImportRow(item: $0, poster: $1) }
    }

    /// Small TMDB posters (w92/w154), fetched in parallel, in input order.
    static func fetchPosters(_ urls: [String?], size: String) async -> [Data?] {
        await withTaskGroup(of: (Int, Data?).self) { group in
            for (index, raw) in urls.enumerated() {
                group.addTask {
                    guard let url = TMDBImage.resized(raw, to: size) else { return (index, nil) }
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 10
                    let data = try? await URLSession.shared.data(for: request).0
                    return (index, data)
                }
            }
            var out = [Data?](repeating: nil, count: urls.count)
            for await (index, data) in group { out[index] = data }
            return out
        }
    }

    /// Refresh after `idleMinutes`, or just after the next item airs if sooner.
    static func nextRefresh(idleMinutes: Double, nextAir: Date?) -> Date {
        let idle = Date.now.addingTimeInterval(idleMinutes * 60)
        guard let nextAir, nextAir > .now else { return idle }
        return min(idle, nextAir.addingTimeInterval(60))
    }
}
