import Foundation
import FusionhaKit

/// Recently added's words: the day heading ("Today", "Yesterday", "Mon",
/// then "3 Nov") and each title's note ("Added 2 h ago" today; else a
/// series' episode count or the time it came in).
enum V2RecentWords {
    static func added(_ item: MediaItem) -> Date? {
        Format.timestamp(item.addedAt) ?? Format.day(item.addedAt)
    }

    static func day(_ added: Date?, now: Date = Date(), calendar: Calendar = .current) -> String {
        guard let added else { return "Earlier" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: added),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ..<1: return "Today"
        case 1: return "Yesterday"
        case 2...6: return added.formatted(.dateTime.weekday(.abbreviated))
        default: return added.formatted(.dateTime.day().month(.abbreviated))
        }
    }

    static func note(_ item: MediaItem, now: Date = Date(), calendar: Calendar = .current) -> String {
        let added = added(item)
        if let added, calendar.isDate(added, inSameDayAs: now) {
            let minutes = Int(now.timeIntervalSince(added) / 60)
            if minutes < 1 { return "Added just now" }
            if minutes < 60 { return "Added \(minutes) min ago" }
            return "Added \(minutes / 60) h ago"
        }
        if item.kind != .movie, let episodes = item.editions.compactMap(\.have).max(), episodes > 0 {
            return episodes == 1 ? "1 episode" : "\(episodes) episodes"
        }
        guard let added else { return "Added" }
        return "Added \(added.formatted(date: .omitted, time: .shortened))"
    }
}
