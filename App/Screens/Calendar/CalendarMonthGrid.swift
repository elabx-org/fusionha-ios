import SwiftUI
import FusionhaKit

/// `MonthView`: weekday header, rounded day cells (solid shelf objects) with up to
/// two event pills and `+N more`. Today is lit cream. Tapping a cell's empty space
/// opens that day in the Day view.
struct MonthGridView: View {
    @Environment(AppModel.self) private var model
    let month: Date
    let entries: [CalendarEntry]
    let todayIso: String
    let firstDay: Int
    let openDay: (String) -> Void

    private var cal: Calendar { CalendarMath.gregorian() }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 4), count: 7)
        let byDay = CalendarMath.groupByDay(entries, cal)
        let cells = CalendarMath.monthGrid(month, firstDay: firstDay, cal)
        let now = Date()
        VStack(spacing: 0) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(CalendarMath.weekdayHeaders(firstDay: firstDay), id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.dim)
                        .padding(.top, 2)
                        .padding(.bottom, 6)
                }
            }
            .accessibilityHidden(true)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(cells.enumerated()), id: \.offset) { index, iso in
                    if let iso {
                        cell(iso, items: byDay[iso] ?? [], now: now)
                            .calReveal(index, stagger: 0.012)
                    } else {
                        Color.clear.frame(minHeight: 76)
                    }
                }
            }
        }
    }

    private func cell(_ iso: String, items: [CalendarEntry], now: Date) -> some View {
        let isToday = iso == todayIso
        let weekday = CalendarMath.weekday(iso: iso, cal)
        let weekend = weekday == 0 || weekday == 6
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return VStack(alignment: .leading, spacing: 4) {
            dayNumber(iso, isToday: isToday)
            ForEach(Array(items.prefix(2).enumerated()), id: \.offset) { _, entry in
                // The pill never widens the 50pt cell: it overflows and is clipped, so
                // the title (the only flexible part) collapses first, like the web.
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: 18, maxHeight: 18)
                    .overlay(alignment: .leading) {
                        Button { model.open(entry.itemId) } label: {
                            MonthPill(entry: entry, now: now)
                        }
                        .buttonStyle(.plain)
                    }
                    .clipped()
            }
            if items.count > 2 {
                Text("+\(items.count - 2) more")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Theme.mut)
                    .padding(.leading, 4)
                    .lineLimit(1)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
        .background(weekend ? Theme.panel2.opacity(0.7) : Theme.card, in: shape)
        .overlay {
            shape.strokeBorder(isToday ? Theme.txt.opacity(0.55) : Theme.line, lineWidth: 1)
        }
        .clipShape(shape)
        .contentShape(shape)
        .onTapGesture { openDay(iso) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(CalendarMath.agendaDayLabel(iso, cal))\(isToday ? ", Today" : ""), \(items.count) scheduled")
        .accessibilityAction(named: "Open day") { openDay(iso) }
    }

    /// The day number; today's sits on a cream disc (the mock's lit `.d.today`).
    private func dayNumber(_ iso: String, isToday: Bool) -> some View {
        Text(iso.suffix(2).hasPrefix("0") ? String(iso.suffix(1)) : String(iso.suffix(2)))
            .font(.system(size: 12, weight: .semibold).monospacedDigit())
            .foregroundStyle(isToday ? Theme.onInk : Theme.mut)
            .frame(minWidth: 20, minHeight: 20)
            .background {
                if isToday {
                    Circle().fill(Theme.txt)
                }
            }
    }
}

/// `.mev`: kind tick, title (collapses first), code, up to three edition dots.
private struct MonthPill: View {
    let entry: CalendarEntry
    let now: Date

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(entry.accent).frame(width: 3, height: 14)
            Text(entry.title)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
                .frame(minWidth: 0, alignment: .leading)
                .layoutPriority(-1)
            Text(entry.label)
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(Theme.mut)
                .lineLimit(1)
                .fixedSize()
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                ForEach(Array(entry.editions.prefix(3).enumerated()), id: \.offset) { _, edition in
                    Circle().fill(entry.statusKey(for: edition, now: now).color).frame(width: 6, height: 6)
                }
            }
            .fixedSize()
        }
        .foregroundStyle(Theme.txt)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .calLivePulse(entry.isGrabbing, shape: RoundedRectangle(cornerRadius: 6, style: .continuous),
                      base: Theme.txt.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.title) · \(entry.label)")
    }
}
