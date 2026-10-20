import SwiftUI
import FusionhaKit

/// The desktop Week (≥1000 of the Calendar's own width, `WeekView` with
/// `calendar_week_layout = stacked`): seven equal day columns, each a head
/// (weekday, date, "N airing") over that day's season drops and episodes in
/// air order, with the now line in today's column. Cards use the server's
/// week card style, as on the web. Shown when the server's
/// `calendar_week_layout` is `stacked`; the default is `WeekTimelineView`.
struct WeekColumnsView: View {
    let days: [String]
    let entries: [CalendarEntry]
    let todayIso: String
    let style: WeekCardStyle

    private var cal: Calendar { CalendarMath.gregorian() }

    var body: some View {
        let byDay = CalendarMath.groupByDay(entries, cal)
        let now = Date()
        HStack(alignment: .top, spacing: 8) {
            ForEach(days, id: \.self) { iso in
                column(iso, entries: byDay[iso] ?? [], now: now)
                    .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func column(_ iso: String, entries: [CalendarEntry], now: Date) -> some View {
        let grouped = CalendarMath.groupWeekDay(entries)
        let count = grouped.singles.count + grouped.seasons.reduce(0) { $0 + $1.entries.count }
        let isToday = iso == todayIso
        let nowIndex: Int? = isToday ? grouped.singles.firstIndex(where: { !$0.hasAired(now: now) }) : nil
        return VStack(alignment: .leading, spacing: 8) {
            WeekColumnHead(iso: iso, isToday: isToday, count: count)
            ForEach(Array(grouped.seasons.enumerated()), id: \.offset) { _, season in
                SeasonDropCard(group: season, style: style, now: now)
            }
            ForEach(Array(grouped.singles.enumerated()), id: \.offset) { index, entry in
                if index == nowIndex { CalNowMarker() }
                WeekEventCard(entry: entry, style: style, now: now)
            }
            if isToday && nowIndex == nil && count > 0 { CalNowMarker() }
            if count == 0 {
                Text("Nothing")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.dim)
                    .padding(.top, 4)
            }
        }
        .padding(8)
        .background(isToday ? Theme.i2.opacity(0.06) : .clear,
                    in: RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
    }
}

/// A day column's head (`week-day-heads`): the short weekday, the date number
/// (the accent on today), and "N airing" under it on the desktop container.
struct WeekColumnHead: View {
    let iso: String
    let isToday: Bool
    let count: Int

    private var cal: Calendar { CalendarMath.gregorian() }

    var body: some View {
        let weekday = CalendarMath.dow[CalendarMath.weekday(iso: iso, cal)]
        let day = Int(iso.suffix(2)) ?? 0
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(weekday.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(isToday ? Theme.accentText : Theme.mut)
                Text("\(day)")
                    .font(.system(size: 20, weight: .bold).monospacedDigit())
                    .foregroundStyle(isToday ? Theme.accentText : Theme.txt)
            }
            Text(count == 0 ? " " : "\(count) airing")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(Theme.dim)
        }
        .padding(.bottom, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(CalendarMath.agendaDayLabel(iso, cal))\(isToday ? ", Today" : ""), \(count) airing")
        .accessibilityAddTraits(.isHeader)
    }
}
