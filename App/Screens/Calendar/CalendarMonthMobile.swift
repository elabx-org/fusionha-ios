import SwiftUI
import FusionhaKit

/// The phone Month (the web's `MonthMobile`): a seven-column grid of day
/// numbers, a dot per show (up to four) and the day's count, with today
/// picked (else the 1st); the picked day is listed in full below. Titles never
/// sit in the grid, so every column stays readable on a phone.
struct MonthMobileView: View {
    let month: Date
    let entries: [CalendarEntry]
    let todayIso: String
    let firstDay: Int
    let cardStyle: WeekCardStyle
    var todayTick = 0

    @Environment(\.calMotionOff) private var motionOff
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var picked: String?

    private var cal: Calendar { CalendarMath.gregorian() }

    var body: some View {
        let byDay = CalendarMath.groupByDay(entries, cal)
        let cells = CalendarMath.monthGrid(month, firstDay: firstDay, cal)
        let days = cells.compactMap { $0 }
        let selected = picked.flatMap { days.contains($0) ? $0 : nil }
            ?? (days.contains(todayIso) ? todayIso : days.first ?? todayIso)
        let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 3), count: 7)
        VStack(alignment: .leading, spacing: 6) {
            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(CalendarMath.weekdayHeaders(firstDay: firstDay), id: \.self) { day in
                    Text(String(day.prefix(1)))
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(0.6)
                        .foregroundStyle(Theme.mut)
                        .padding(.bottom, 6)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, iso in
                    if let iso {
                        MonthMobileCell(iso: iso, entries: byDay[iso] ?? [], todayIso: todayIso,
                                        selected: iso == selected) {
                            picked = iso
                        }
                    } else {
                        Color.clear.frame(height: 56)
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: selected)
            WeekDayGroup(iso: selected, entries: byDay[selected] ?? [], isToday: selected == todayIso, style: cardStyle)
                .id(selected)
                .transition(motionOff || reduceMotion ? .identity : .opacity.combined(with: .offset(y: 4)))
        }
        .animation(motionOff || reduceMotion ? nil : .easeOut(duration: 0.2), value: selected)
        .onChange(of: todayTick) { picked = nil }
    }
}

/// One day: the number (today ringed, the picked day filled), a dot per show
/// and the count.
private struct MonthMobileCell: View {
    let iso: String
    let entries: [CalendarEntry]
    let todayIso: String
    let selected: Bool
    let pick: () -> Void

    var body: some View {
        let isToday = iso == todayIso
        let past = iso < todayIso
        let shows = Self.shows(entries)
        Button(action: pick) {
            VStack(spacing: 4) {
                Text("\(Int(iso.suffix(2)) ?? 0)")
                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                    .foregroundStyle(selected ? Theme.onAccent : isToday ? Theme.grab : past ? Theme.mut : Theme.txt)
                    .frame(width: 28, height: 28)
                    .background {
                        if selected { Circle().fill(Theme.i1) }
                        else if isToday { Circle().strokeBorder(Theme.grab.opacity(0.6), lineWidth: 1.5) }
                    }
                HStack(spacing: 2) {
                    ForEach(shows, id: \.self) { title in
                        Circle().fill(Self.hue(title)).frame(width: 6, height: 6)
                    }
                }
                .frame(height: 6)
                Text(entries.isEmpty ? " " : "\(entries.count)")
                    .font(.system(size: 11, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.dim)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.vertical, 5)
            .background {
                if selected { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.i1.opacity(0.2)) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(CalendarMath.weekDayLabel(iso, CalendarMath.gregorian())), \(entries.count) airing")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Up to four distinct shows, in order.
    static func shows(_ entries: [CalendarEntry]) -> [String] {
        var seen = Set<Int>()
        return entries.compactMap { seen.insert($0.itemId).inserted ? $0.title : nil }.prefix(4).map { $0 }
    }

    /// A steady colour per show from its title (posters carry none), like the web.
    static func hue(_ title: String) -> Color {
        // Monochrome: shades, never hues.
        if Theme.isMono { return Theme.txt.opacity(0.35 + Double(title.count % 5) * 0.12) }
        let h = title.unicodeScalars.reduce(0) { ($0 * 31 + Int($1.value)) % 360 }
        return Color(hue: Double(h) / 360, saturation: 0.55, brightness: 0.78)
    }
}
