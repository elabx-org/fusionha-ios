import Foundation
import FusionhaKit

/// One row of a Home timeline: the title, the day heading it sits under
/// and its note. Recently added makes one per title (`V2RecentWords`);
/// Recently arrived one per title per day it had imports (`RecentArrivals`).
struct V2TimelineEntry: Identifiable {
    let id: String
    let item: MediaItem
    /// When it was added, or the newest import that day.
    let date: Date?
    let day: String
    let note: String
}

/// Home's two timelines (owner 2026-11-09): what joined the library, and
/// what had something imported.
enum V2TimelinePage: Int, CaseIterable, Identifiable {
    case added = 0
    case arrived = 1
    var id: Int { rawValue }

    var title: String { self == .added ? "Recently added" : "Recently arrived" }
}

enum V2TimelineEntries {
    static func added(_ items: [MediaItem], now: Date = Date()) -> [V2TimelineEntry] {
        items.map { item in
            V2TimelineEntry(id: "a\(item.id)", item: item, date: V2RecentWords.added(item),
                            day: V2RecentWords.day(V2RecentWords.added(item), now: now),
                            note: V2RecentWords.note(item, now: now))
        }
    }

    /// Rows whose title is no longer in the library are left out.
    static func arrived(_ rows: [ArrivalRow], library: [Int: MediaItem], now: Date = Date()) -> [V2TimelineEntry] {
        rows.compactMap { row in
            guard let item = library[row.itemId] else { return nil }
            return V2TimelineEntry(id: "r" + row.id, item: item, date: row.latest,
                                   day: V2RecentWords.day(row.day, now: now),
                                   note: RecentArrivals.note(row, now: now))
        }
    }

    /// The days in order, each with its rows (the full page's sections).
    static func days(_ entries: [V2TimelineEntry]) -> [V2TimelineDay] {
        var out: [V2TimelineDay] = []
        for entry in entries {
            if out.last?.day == entry.day {
                out[out.count - 1].entries.append(entry)
            } else {
                out.append(V2TimelineDay(id: "\(out.count)-\(entry.day)", day: entry.day, entries: [entry]))
            }
        }
        return out
    }

    /// Titles added in the last 30 days, newest first, files or not: the
    /// full Recently added page ("See all N" counts the same titles).
    static func lastMonth(_ library: [MediaItem], now: Date = Date()) -> [MediaItem] {
        let since = now.addingTimeInterval(-30 * 86_400)
        var dated: [(item: MediaItem, at: Date)] = []
        for item in library {
            guard let at = V2RecentWords.added(item), at <= now, at >= since else { continue }
            dated.append((item, at))
        }
        dated.sort { a, b in
            if a.at != b.at { return a.at > b.at }
            return a.item.id < b.item.id
        }
        return dated.map { $0.item }
    }
}

/// One day's rows on the full timeline page.
struct V2TimelineDay: Identifiable {
    let id: String
    let day: String
    var entries: [V2TimelineEntry]
}
