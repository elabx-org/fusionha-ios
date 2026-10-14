import SwiftUI
import FusionhaKit

// MARK: - Agenda / Forecast / Day

/// `GroupedDayList`: a day heading per day (`Today  Monday 13 October`), then one
/// row per entry, with the live "now" line in today's group. Only days with
/// entries are listed.
struct GroupedDayList: View {
    let entries: [CalendarEntry]
    let todayIso: String
    let emptyMessage: String
    let quip: String?

    private var cal: Calendar { CalendarMath.gregorian() }

    var body: some View {
        if entries.isEmpty {
            CalEmptyState(message: emptyMessage, quip: quip)
                .padding(.top, 12)
        } else {
            let byDay = CalendarMath.groupByDay(entries, cal)
            let days = byDay.keys.sorted()
            let dayIndex = Dictionary(uniqueKeysWithValues: days.enumerated().map { ($0.element, $0.offset) })
            let now = Date()
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(days, id: \.self) { iso in
                    DayGroup(iso: iso, entries: byDay[iso] ?? [], isToday: iso == todayIso, now: now)
                        .calReveal(dayIndex[iso] ?? 0, stagger: 0.04)
                        .id("day-\(iso)")
                }
            }
        }
    }
}

/// One day: its heading, then its rows, with the now line before the first
/// entry still to air (or after the last, once everything today has aired).
struct DayGroup: View {
    let iso: String
    let entries: [CalendarEntry]
    let isToday: Bool
    let now: Date

    var body: some View {
        let nowIndex: Int? = isToday ? entries.firstIndex(where: { !$0.hasAired(now: now) }) : nil
        VStack(alignment: .leading, spacing: 0) {
            CalDayHeader(iso: iso, isToday: isToday, count: entries.count, noun: "event")
                .padding(.top, 22)
                .padding(.bottom, 6)
            ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                if index == nowIndex {
                    CalNowMarker()
                }
                AgendaRow(entry: entry, now: now)
            }
            if isToday && nowIndex == nil && !entries.isEmpty {
                CalNowMarker()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// `.day-h`: `Today  Monday 13 October` / `Wednesday  15 October`, with the
/// day's count trailing.
struct CalDayHeader: View {
    let iso: String
    let isToday: Bool
    let count: Int
    var noun = "event"

    private var cal: Calendar { CalendarMath.gregorian() }

    private var weekdayName: String {
        CalendarMath.weekdayNames[CalendarMath.weekday(iso: iso, cal)]
    }

    private var dateText: String {
        let day = Int(iso.dropFirst(8).prefix(2)) ?? 0
        let month = Int(iso.dropFirst(5).prefix(2)) ?? 1
        let name = CalendarMath.monthNames[min(max(month - 1, 0), 11)]
        return "\(day) \(name)"
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(isToday ? "Today" : weekdayName)
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(Theme.txt)
                .lineLimit(1)
                .fixedSize()
            Text(isToday ? "\(weekdayName) \(dateText)" : dateText)
                .font(.system(size: 15))
                .foregroundStyle(Theme.dim)
                .lineLimit(1)
            Spacer(minLength: 8)
            if count > 0 {
                Text("\(count) \(noun)\(count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(Theme.dim)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(CalendarMath.agendaDayLabel(iso, cal))\(isToday ? ", Today" : ""), \(count) \(noun)\(count == 1 ? "" : "s")")
        .accessibilityAddTraits(.isHeader)
    }
}

/// The live "now" line (`.now`): the time on a cream tag, then a cream rule.
struct CalNowMarker: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            HStack(spacing: 8) {
                Text(CalendarMath.clock(context.date))
                    .font(.system(size: 11, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.onInk)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.txt, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                Rectangle()
                    .fill(Theme.txt.opacity(0.7))
                    .frame(height: 1.5)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Now, \(CalendarMath.clock(context.date))")
        }
        .padding(.vertical, 4)
    }
}
