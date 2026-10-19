import SwiftUI
import FusionhaKit

// One phone day (`calendar/mobile/MobileDayBlock`): a 14pt date head with the
// airing count, then full-width cards with 2+ same-show episodes folded into
// runs. Today lists what has aired, the now line, then what is still to come.

/// The day's head (`.mhead`): `Today · Wed 7` in the now colour, past days
/// dimmed, then `N airings`. Opaque so it can pin over the list.
struct PhoneDayHead: View {
    let iso: String
    let todayIso: String
    let count: Int

    var body: some View {
        let isToday = iso == todayIso
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(CalendarMath.mobileDayLabel(iso, todayIso: todayIso, CalendarMath.gregorian()))
                .font(.system(size: 14, weight: .heavy))
                .tracking(-0.14)
                .foregroundStyle(isToday ? Theme.grab : iso < todayIso ? Theme.mut : Theme.txt)
            Text("\(count) airing\(count == 1 ? "" : "s")")
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(Theme.mut)
            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bg)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The cards of one phone day (`.mlist`), with today's now line.
struct PhoneDayCards: View {
    let iso: String
    let entries: [CalendarEntry]
    let todayIso: String

    var body: some View {
        let now = Date()
        let items = CalendarMath.dayItems(entries)
        let split = CalendarMath.phoneDay(items, isToday: iso == todayIso, now: now)
        VStack(alignment: .leading, spacing: 8) {
            if entries.isEmpty {
                Text("Nothing airing")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.dim)
                    .frame(minHeight: 44, alignment: .leading)
            }
            ForEach(split.before) { item in PhoneDayItemView(item: item, now: now) }
            if split.showsNow { PhoneNowLine() }
            ForEach(split.after) { item in PhoneDayItemView(item: item, now: now) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A whole day with an inline (unpinned) head: Week and the Month day panel.
struct PhoneDayBlock: View {
    let iso: String
    let entries: [CalendarEntry]
    let todayIso: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PhoneDayHead(iso: iso, todayIso: todayIso, count: entries.count)
            PhoneDayCards(iso: iso, entries: entries, todayIso: todayIso)
        }
    }
}

private struct PhoneDayItemView: View {
    let item: CalendarDayItem
    let now: Date

    var body: some View {
        switch item {
        case .run(let group): PhoneCalRun(group: group, now: now)
        case .entry(let entry): PhoneCalCard(entry: entry, now: now)
        }
    }
}

/// `.mnow`: `NOW 9:41 PM`, a dot and a solid rule in the now colour.
struct PhoneNowLine: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            HStack(spacing: 8) {
                Circle()
                    .fill(Theme.grab)
                    .frame(width: 8, height: 8)
                    .background(Circle().fill(Theme.grab.opacity(0.25)).padding(-3))
                Text("now \(CalendarMath.clock(context.date))")
                    .font(.system(size: 11, weight: .heavy).monospacedDigit())
                    .tracking(0.55)
                    .foregroundStyle(Theme.grab)
                    .fixedSize()
                Rectangle()
                    .fill(Theme.grab.opacity(0.5))
                    .frame(height: 1)
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Now, \(CalendarMath.clock(context.date))")
        }
    }
}

/// Forecast's empty day / Agenda's empty month (`.memptyRow`).
struct PhoneEmptyRow: View {
    var day: String?
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            if let day {
                Text(day)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.mut)
                    .frame(width: 72, alignment: .leading)
            }
            Text(message).foregroundStyle(Theme.dim)
            Spacer(minLength: 0)
        }
        .font(.system(size: 12.5))
        .frame(minHeight: 44)
    }
}
