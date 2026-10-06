import SwiftUI
import FusionhaKit

/// Day and time words for Up next, in the device's locale (`21:00` or `9:00 PM`).
enum WidgetDay {
    /// `Tonight` (today from 5 pm), `Today`, `Tomorrow`, then `Thu` or, long,
    /// `Thursday`; beyond a week `Oct 12`.
    static func label(_ date: Date, hasTime: Bool, long: Bool = false, now: Date = .now) -> String {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) {
            return hasTime && calendar.component(.hour, from: date) >= 17 ? "Tonight" : "Today"
        }
        let short = WidgetFeeds.whenLabel(date, hasTime: false, now: now)
        guard long, short.count == 3 else { return short }
        return date.formatted(.dateTime.weekday(.wide))
    }
}

/// The air time in the device's locale, or `All day` for a date-only release.
struct WidgetAirClock: View {
    let item: UpNextItem
    var size: CGFloat = 15

    var body: some View {
        Group {
            if item.hasTime {
                Text(item.airDate, format: .dateTime.hour().minute())
            } else {
                Text("All day")
            }
        }
        .font(WidgetStyle.numeral(size))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}
