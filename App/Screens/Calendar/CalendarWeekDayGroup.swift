import SwiftUI
import FusionhaKit

/// One day of the Week agenda: the `.day-h` heading, season drops, then the
/// single episodes with the live now line before the first still to air. An
/// empty day (other than today) folds to one quiet dashed line.
struct WeekDayGroup: View {
    let iso: String
    let entries: [CalendarEntry]
    let isToday: Bool
    let style: WeekCardStyle

    private var cal: Calendar { CalendarMath.gregorian() }

    var body: some View {
        let grouped = CalendarMath.groupWeekDay(entries)
        let count = grouped.singles.count + grouped.seasons.reduce(0) { $0 + $1.entries.count }
        if count == 0 && !isToday {
            emptyDay
        } else {
            let now = Date()
            let nowIndex: Int? = isToday ? grouped.singles.firstIndex(where: { !$0.hasAired(now: now) }) : nil
            VStack(alignment: .leading, spacing: 8) {
                CalDayHeader(iso: iso, isToday: isToday, count: count, noun: "airing")
                    .padding(.top, 18)
                if count == 0 {
                    Text("Nothing scheduled today").font(.system(size: 13)).foregroundStyle(Theme.dim)
                }
                ForEach(Array(grouped.seasons.enumerated()), id: \.offset) { _, season in
                    SeasonDropCard(group: season, style: style, now: now)
                }
                ForEach(Array(grouped.singles.enumerated()), id: \.offset) { index, entry in
                    if index == nowIndex {
                        CalNowMarker()
                    }
                    WeekEventCard(entry: entry, style: style, now: now)
                }
                if isToday && nowIndex == nil {
                    CalNowMarker()
                }
            }
        }
    }

    private var emptyDay: some View {
        let weekday = CalendarMath.weekday(iso: iso, cal)
        let day = Int(iso.suffix(2)) ?? 0
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("\(CalendarMath.dow[weekday]) \(day)")
                .fontWeight(.semibold)
                .foregroundStyle(Theme.mut)
                .frame(width: 66, alignment: .leading)
            Text("Nothing scheduled")
            Spacer(minLength: 0)
        }
        .font(.system(size: 13))
        .foregroundStyle(Theme.dim)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            CalDashLine().stroke(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3])).frame(height: 1)
        }
    }
}

private struct CalDashLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
