import Foundation
import WidgetKit
import FusionhaKit

// Timeline entries and the loader for the home-screen widgets. Lives in Shared so
// the app's debug widget gallery (CI screenshots) renders the same views with the
// same data path the widget extension uses.

struct DownloadsEntry: TimelineEntry {
    struct Row: Hashable {
        let itemId: Int
        let title: String
        let tier: QualityTier
        let fraction: Double
        let stalled: Bool
        let poster: Data?
    }

    let date: Date
    let total: Int
    let rows: [Row]
    let signedIn: Bool
    let failed: Bool
    var report: String = ""
    /// Shown while nothing is downloading.
    var upNext: [UpNextRow] = []
    var recent: [RecentImportRow] = []

    var idle: Bool { total == 0 && rows.isEmpty }

    static let placeholder = DownloadsEntry(
        date: .now, total: 2,
        rows: [
            Row(itemId: 0, title: "Dune: Part Two", tier: .uhd, fraction: 0.62, stalled: false, poster: nil),
            Row(itemId: 0, title: "Shōgun · S01E04", tier: .hd, fraction: 0.18, stalled: false, poster: nil),
        ],
        signedIn: true, failed: false)
}

struct UpNextRow: Hashable {
    let item: UpNextItem
    let poster: Data?
}

struct RecentImportRow: Hashable {
    let item: RecentImport
    let poster: Data?
}

struct UpNextEntry: TimelineEntry {
    let date: Date
    let rows: [UpNextRow]
    let signedIn: Bool
    let failed: Bool

    static let placeholder = UpNextEntry(date: .now, rows: WidgetSamples.upNext, signedIn: true, failed: false)
}

struct RecentEntry: TimelineEntry {
    let date: Date
    let rows: [RecentImportRow]
    let signedIn: Bool
    let failed: Bool

    static let placeholder = RecentEntry(date: .now, rows: WidgetSamples.recent, signedIn: true, failed: false)
}

/// Deep links the app's `onOpenURL` understands.
enum WidgetLink {
    static let activity = URL(string: "fusionha://activity")!
    static let calendar = URL(string: "fusionha://calendar")!
    static let library = URL(string: "fusionha://library")!

    static func item(_ id: Int?) -> URL? {
        guard let id, id > 0 else { return nil }
        return URL(string: "fusionha://item/\(id)")
    }
}

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
                    tier: item.tier, fraction: item.fraction, stalled: item.stalled, poster: poster)
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

/// Gallery placeholders (WidgetKit `placeholder(in:)` renders them redacted).
enum WidgetSamples {
    static let upNext: [UpNextRow] = [
        UpNextRow(item: UpNextItem(itemId: 0, title: "Shōgun", code: "S1·E5", episodeTitle: "Broken to the Fist",
                                   airDate: .now.addingTimeInterval(3 * 3600), hasTime: true, isMovie: false,
                                   isAnime: false, posterUrl: nil,
                                   editions: [UpNextEdition(tier: .hd, status: .unaired),
                                              UpNextEdition(tier: .uhd, status: .unaired)]),
                  poster: nil),
        UpNextRow(item: UpNextItem(itemId: 0, title: "Dune: Part Two", code: "Digital", episodeTitle: nil,
                                   airDate: .now.addingTimeInterval(2 * 86_400), hasTime: false, isMovie: true,
                                   isAnime: false, posterUrl: nil,
                                   editions: [UpNextEdition(tier: .uhd, status: .unaired)]),
                  poster: nil),
        UpNextRow(item: UpNextItem(itemId: 0, title: "Frieren", code: "#29", episodeTitle: nil,
                                   airDate: .now.addingTimeInterval(4 * 86_400), hasTime: true, isMovie: false,
                                   isAnime: true, posterUrl: nil,
                                   editions: [UpNextEdition(tier: .hd, status: .unaired)]),
                  poster: nil),
    ]

    static let recent: [RecentImportRow] = ["The Matrix", "Inception", "Breaking Bad", "Cowboy Bebop", "Arrival"]
        .map { RecentImportRow(item: RecentImport(itemId: nil, title: $0, tiers: [.hd], importedAt: .now, posterUrl: nil, count: 1),
                         poster: nil) }
}
