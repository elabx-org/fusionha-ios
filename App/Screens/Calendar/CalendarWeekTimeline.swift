import SwiftUI
import FusionhaKit

/// The desktop Week's timeline (≥1000 of the Calendar's own width, web
/// `WeekView` layout `timeline`, the default): a time gutter (Early 12a, Day
/// 6a, Prime 5p, Late 9p) beside seven day columns, cut into four bands that
/// line up across the week. Each day's season drops and episodes sit in the
/// band of their local air hour; today's column is tinted and the now line is
/// spliced into the current band between aired and upcoming cards. One solid
/// content card: no glass.
struct WeekTimelineView: View {
    let days: [String]
    let entries: [CalendarEntry]
    let todayIso: String
    let style: WeekCardStyle

    @State private var width: CGFloat = 0
    private static let gutter: CGFloat = 56
    private var cal: Calendar { CalendarMath.gregorian() }

    /// Seven equal columns after the gutter and hairlines. The web floors them
    /// at 140 and scrolls; at 1000 that would overflow, so they share the width.
    private var column: CGFloat {
        max((width - Self.gutter - 7) / 7, 0)
    }

    var body: some View {
        let byDay = CalendarMath.groupByDay(entries, cal)
        let grouped = days.map { CalendarMath.groupWeekDay(byDay[$0] ?? []) }
        let now = Date()
        let nowBand = CalendarBand.now(now, cal)
        VStack(spacing: 0) {
            row(minHeight: 0) {
                Color.clear.frame(width: Self.gutter)
                ForEach(Array(days.enumerated()), id: \.offset) { i, iso in
                    let g = grouped[i]
                    WeekColumnHead(iso: iso, isToday: iso == todayIso,
                                   count: g.singles.count + g.seasons.reduce(0) { $0 + $1.entries.count })
                        .padding(.vertical, 6)
                        .frame(width: column)
                        .background(iso == todayIso ? Theme.i2.opacity(0.06) : .clear)
                }
            }
            ForEach(CalendarBand.allCases, id: \.self) { band in
                Theme.line.frame(height: 1)
                row(minHeight: band.minHeight) {
                    BandGutter(band: band).frame(width: Self.gutter)
                    ForEach(Array(days.enumerated()), id: \.offset) { i, iso in
                        let isToday = iso == todayIso
                        let cell = WeekBandCell.make(seasons: grouped[i].seasons, singles: grouped[i].singles,
                                                     band: band, isNowCell: isToday && band == nowBand, now: now, cal)
                        BandCellView(cell: cell, style: style, now: now)
                            .frame(width: column)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .background(isToday ? Theme.i2.opacity(0.06) : .clear)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .accessibilityElement(children: .contain)
    }

    /// One band (or the head row): the gutter and seven cells, all as tall as
    /// the tallest, with hairlines between the columns.
    private func row<Content: View>(minHeight: Double, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Group(subviews: content()) { cells in
                ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                    if index > 0 { Theme.line.frame(width: 1).frame(maxHeight: .infinity) }
                    cell
                }
            }
        }
        .frame(minHeight: minHeight, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The gutter beside a band: its opening time top right, its name bottom left.
private struct BandGutter: View {
    let band: CalendarBand

    var body: some View {
        VStack(spacing: 0) {
            Text(band.timeLabel)
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(Theme.mut)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Spacer(minLength: 8)
            Text(band.label.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(Theme.mut.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(6)
        .frame(maxHeight: .infinity)
        .background(Theme.panel2.opacity(0.45))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(band.label), from \(band.timeLabel)")
        .accessibilityAddTraits(.isHeader)
    }
}

/// One day-and-band cell: its cards top to bottom, the now line where it falls.
private struct BandCellView: View {
    let cell: WeekBandCell
    let style: WeekCardStyle
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(cell.cards.enumerated()), id: \.offset) { index, card in
                if index == cell.nowIndex { CalNowMarker() }
                switch card {
                case .season(let group): SeasonDropCard(group: group, style: style, now: now)
                case .single(let entry): WeekEventCard(entry: entry, style: style, now: now)
                }
            }
            if let nowIndex = cell.nowIndex, nowIndex == cell.cards.count { CalNowMarker() }
        }
        .padding(6)
    }
}
