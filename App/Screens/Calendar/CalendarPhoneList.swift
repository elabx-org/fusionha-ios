import SwiftUI
import FusionhaKit

/// Forecast · Day · Agenda on a phone (`calendar/mobile/MobileDayList`): full-width
/// cards under sticky date heads.
/// - Forecast: every day of the window; an empty day is a slim one-liner.
/// - Agenda: only days with airings (the screen lands on today).
/// - Day: the week strip, the day, then an "Up next" card.
struct PhoneDayList: View {
    enum Kind { case forecast, day, agenda }

    let kind: Kind
    /// The visible days in order (Day: just the anchored day).
    let days: [String]
    /// The filtered entries of the fetched range (the shown days ±1).
    let entries: [CalendarEntry]
    let todayIso: String
    var firstDay = 0
    var onPickDay: (String) -> Void = { _ in }

    private var cal: Calendar { CalendarMath.gregorian() }

    var body: some View {
        let byDay = CalendarMath.groupByDay(entries, cal)
        let shown = kind == .agenda ? days.filter { !(byDay[$0] ?? []).isEmpty } : days
        LazyVStack(alignment: .leading, spacing: 4, pinnedViews: [.sectionHeaders]) {
            if kind == .day, let day = days.first {
                PhoneDayStrip(selected: day, todayIso: todayIso, firstDay: firstDay, byDay: byDay,
                              known: Set((-1...1).map { CalendarMath.shift(day, days: $0, cal) }),
                              onPick: onPickDay)
            }
            if kind == .agenda && shown.isEmpty {
                PhoneEmptyRow(message: "Nothing scheduled this month")
            }
            ForEach(shown, id: \.self) { iso in
                let list = byDay[iso] ?? []
                if kind == .forecast && list.isEmpty && iso != todayIso {
                    PhoneEmptyRow(day: shortDay(iso), message: "Nothing airing")
                        .id("day-\(iso)")
                } else {
                    Section {
                        PhoneDayCards(iso: iso, entries: list, todayIso: todayIso)
                    } header: {
                        PhoneDayHead(iso: iso, todayIso: todayIso, count: list.count)
                    }
                    .id("day-\(iso)")
                }
            }
            if kind == .day, let day = days.first {
                let next = CalendarMath.shift(day, days: 1, cal)
                PhoneUpNextCard(iso: next, entries: byDay[next] ?? []) { onPickDay(next) }
                    .padding(.top, 14)
            }
        }
    }

    private func shortDay(_ iso: String) -> String {
        "\(CalendarMath.dow[CalendarMath.weekday(iso: iso, cal)]) \(Int(iso.suffix(2)) ?? 0)"
    }
}

/// Day's "Up next" card (`UpNextCard`): the next day's airing count and first
/// three titles; tapping it steps to that day.
private struct PhoneUpNextCard: View {
    let iso: String
    let entries: [CalendarEntry]
    let action: () -> Void

    var body: some View {
        let cal = CalendarMath.gregorian()
        let titles = CalendarMath.upNextTitles(entries).joined(separator: ", ")
        let label = "Up next · \(CalendarMath.dow[CalendarMath.weekday(iso: iso, cal)]) \(Int(iso.suffix(2)) ?? 0)"
        Button(action: action) {
            HStack(spacing: 10) {
                Text(label)
                    .fontWeight(.heavy)
                    .foregroundStyle(Theme.txt)
                    .lineLimit(1)
                    .fixedSize()
                Text("\(entries.count) airing\(titles.isEmpty ? "" : " · \(titles)")")
                    .foregroundStyle(Theme.mut)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.mut)
            }
            .font(.system(size: 13))
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.panel)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.i1.opacity(0.12)))
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Day view's week strip (`MobileDayStrip`): seven day tabs with the airing
/// count (`–` when none, left out when that day was not fetched).
private struct PhoneDayStrip: View {
    let selected: String
    let todayIso: String
    let firstDay: Int
    let byDay: [String: [CalendarEntry]]
    /// Days whose counts are known (the fetched range).
    let known: Set<String>
    let onPick: (String) -> Void

    var body: some View {
        let cal = CalendarMath.gregorian()
        let days = CalendarMath.date(selected, cal).map { CalendarMath.weekDays($0, firstDay: firstDay, cal) } ?? []
        HStack(spacing: 5) {
            ForEach(days, id: \.self) { iso in
                let on = iso == selected
                let n: Int? = known.contains(iso) || on ? (byDay[iso]?.count ?? 0) : nil
                Button {
                    if !on { onPick(iso) }
                } label: {
                    VStack(spacing: 3) {
                        Text(CalendarMath.dow[CalendarMath.weekday(iso: iso, cal)])
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(0.77)
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.mut)
                        Text(verbatim: "\(Int(iso.suffix(2)) ?? 0)")
                            .font(.system(size: 16, weight: .heavy).monospacedDigit())
                            .foregroundStyle(iso == todayIso ? Theme.grab : Theme.txt)
                        if let n {
                            Text(verbatim: n == 0 ? "–" : "\(n)")
                                .font(.system(size: 11, weight: .bold).monospacedDigit())
                                .foregroundStyle(Theme.dim)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.card)
                            .overlay {
                                if on { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.i1.opacity(0.22)) }
                            }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(CalendarMath.weekDayLabel(iso, cal))\(iso == todayIso ? ", Today" : "")\(n.map { ", \($0) airing" } ?? "")")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.vertical, 6)
        .sensoryFeedback(.selection, trigger: selected)
    }
}
