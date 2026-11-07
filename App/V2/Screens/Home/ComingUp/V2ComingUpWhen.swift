import Foundation

/// The day words on a "Coming up" card: "today" (or "tonight" for a timed
/// airing from 5 pm), "tomorrow", the weekday within six days ("Tue"),
/// else the day and month in the viewer's order ("2 Dec").
enum V2ComingUpWhen {
    static func words(_ at: Date, timed: Bool, now: Date = Date(), calendar: Calendar = .current) -> String {
        let today = calendar.startOfDay(for: now)
        let day = calendar.startOfDay(for: at)
        let ahead = calendar.dateComponents([.day], from: today, to: day).day ?? 0
        switch ahead {
        case 0:
            return timed && calendar.component(.hour, from: at) >= 17 ? "tonight" : "today"
        case 1:
            return "tomorrow"
        case 2...6:
            return format(at, template: "EEE", calendar: calendar)
        default:
            return format(at, template: "dMMM", calendar: calendar)
        }
    }

    private static func format(_ date: Date, template: String, calendar: Calendar) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate(template)
        return f.string(from: date)
    }
}
