import SwiftUI
import FusionhaKit

/// The web's mobile Week (`WeekMobile`): a pinned header (slim bar once the toolbar
/// has folded away, then the day strip) over an agenda of all seven days, which is
/// the only scroller. Season drops (≥ 3 same-day episodes) collapse into one card.
struct WeekMobileView: View {
    let days: [String]
    let entries: [CalendarEntry]
    let todayIso: String
    let cardStyle: WeekCardStyle
    @Binding var collapsed: Bool
    let title: String
    let onPrev: () -> Void
    let onToday: () -> Void
    let onNext: () -> Void

    @Environment(\.calMotionOff) private var motionOff
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selected: String?

    private var cal: Calendar { CalendarMath.gregorian() }
    private var animated: Bool { !(motionOff || reduceMotion) }
    private var defaultDay: String { days.contains(todayIso) ? todayIso : days[0] }
    private var activeDay: String { selected.flatMap { days.contains($0) ? $0 : nil } ?? defaultDay }

    var body: some View {
        let byDay = CalendarMath.groupByDay(entries, cal)
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                header(byDay: byDay, proxy: proxy)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(Array(days.enumerated()), id: \.element) { index, iso in
                            WeekDayGroup(iso: iso, entries: byDay[iso] ?? [], isToday: iso == todayIso, style: cardStyle)
                                .calReveal(index, stagger: 0.02)
                                .id("week-\(iso)")
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    geo.contentOffset.y + geo.contentInsets.top
                } action: { _, y in
                    // Hysteresis: fold past 48pt, unfold only back within 8pt of the top.
                    let next = collapsed ? y >= 8 : y > 48
                    if next != collapsed { collapsed = next }
                }
            }
            .task(id: days.first) {
                guard days.contains(todayIso) else { return }
                try? await Task.sleep(for: .milliseconds(60))
                proxy.scrollTo("week-\(todayIso)", anchor: .top)
            }
        }
    }

    private func header(byDay: [String: [CalendarEntry]], proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            if collapsed {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Theme.txt)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    CalNavButtons(noun: "week", onPrev: onPrev, onToday: onToday, onNext: onNext)
                }
                .padding(.top, 8)
                .padding(.horizontal, 2)
                .padding(.bottom, 2)
                .transition(animated ? .opacity.combined(with: .offset(y: -4)).animation(.easeOut(duration: 0.2)) : .identity)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { iso in
                        dayChip(iso, entries: byDay[iso] ?? []) {
                            selected = iso
                            if animated {
                                withAnimation(.smooth) { proxy.scrollTo("week-\(iso)", anchor: .top) }
                            } else {
                                proxy.scrollTo("week-\(iso)", anchor: .top)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 10)
        .background(Color(hex: 0x0B0C0F).opacity(0.96))
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    private func dayChip(_ iso: String, entries: [CalendarEntry], action: @escaping () -> Void) -> some View {
        let isToday = iso == todayIso
        let on = activeDay == iso
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return Button(action: action) {
            VStack(spacing: 4) {
                Text(CalendarMath.dow[CalendarMath.weekday(iso: iso, cal)].uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.72)
                    .foregroundStyle(Theme.mut)
                Text("\(Int(iso.suffix(2)) ?? 0)")
                    .font(.system(size: 17, weight: .heavy).monospacedDigit())
                    .foregroundStyle(isToday ? Theme.grab : Theme.txt)
                HStack(spacing: 3) {
                    ForEach(CalendarEntry.statusKeys(entries), id: \.self) { key in
                        Circle().fill(key.color).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(minWidth: 44)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(on ? Theme.grab.opacity(0.06) : Theme.card, in: shape)
            .background(Theme.card, in: shape)
            .overlay(shape.strokeBorder(on ? Theme.grab.opacity(0.55) : Theme.line))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(CalendarMath.weekDayLabel(iso, cal))\(isToday ? ", Today" : "")")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

private struct WeekDayGroup: View {
    let iso: String
    let entries: [CalendarEntry]
    let isToday: Bool
    let style: WeekCardStyle

    private var cal: Calendar { CalendarMath.gregorian() }

    var body: some View {
        let grouped = CalendarMath.groupWeekDay(entries)
        let count = grouped.singles.count + grouped.seasons.reduce(0) { $0 + $1.entries.count }
        let weekday = CalendarMath.weekday(iso: iso, cal)
        let day = Int(iso.suffix(2)) ?? 0
        if count == 0 && !isToday {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(CalendarMath.dow[weekday]) \(day)")
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.mut)
                    .frame(width: 66, alignment: .leading)
                Text("Nothing scheduled")
                Spacer(minLength: 0)
            }
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.dim)
            .padding(.vertical, 10)
            .padding(.horizontal, 2)
            .overlay(alignment: .bottom) {
                Line().stroke(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3])).frame(height: 1)
            }
        } else {
            let now = Date()
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(CalendarMath.weekdayNames[weekday]) \(day)")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(isToday ? Theme.grab : Theme.txt)
                    if count > 0 {
                        Text("\(count) airing\(count == 1 ? "" : "s")")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.mut)
                    }
                    Rectangle().fill(Theme.line).frame(height: 1).alignmentGuide(.firstTextBaseline) { $0[.bottom] + 3 }
                }
                if isToday {
                    TimelineView(.everyMinute) { context in
                        HStack(spacing: 7) {
                            Circle().fill(Theme.grab).frame(width: 7, height: 7)
                                .background(Circle().fill(Theme.grab.opacity(0.25)).frame(width: 13, height: 13))
                            LinearGradient(colors: [Theme.grab, .clear], startPoint: .leading, endPoint: .trailing)
                                .frame(height: 1)
                            Text("now \(CalendarMath.clock(context.date))")
                                .font(.system(size: 9.5, weight: .heavy).monospacedDigit())
                                .tracking(0.48)
                                .foregroundStyle(Theme.grab)
                                .fixedSize()
                        }
                    }
                }
                if count == 0 {
                    Text("Nothing scheduled today").font(.system(size: 12.5)).foregroundStyle(Theme.dim)
                }
                ForEach(Array(grouped.seasons.enumerated()), id: \.offset) { _, season in
                    SeasonDropCard(group: season, style: style, now: now)
                }
                ForEach(Array(grouped.singles.enumerated()), id: \.offset) { _, entry in
                    WeekEventCard(entry: entry, style: style, now: now)
                }
            }
        }
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

// MARK: Cards

/// The shared card chrome: radius 12, hairline, card fill (tier-tinted for `accent`),
/// dimmed once aired, breathing while an edition is grabbing.
private struct WeekCardChrome: ViewModifier {
    let style: WeekCardStyle
    let tier: QualityTier
    let aired: Bool
    let live: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        let accent = style == .accent
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(accent ? tier.color.opacity(0.13) : .clear, in: shape)
            .calLivePulse(live, shape: shape, base: Theme.card)
            .clipShape(shape)
            .overlay(shape.strokeBorder(accent ? tier.color.opacity(0.38) : Theme.line))
            .opacity(aired ? 0.55 : 1)
            .contentShape(shape)
    }
}

private struct WeekEventCard: View {
    @Environment(AppModel.self) private var model
    let entry: CalendarEntry
    let style: WeekCardStyle
    let now: Date

    var body: some View {
        Button { model.open(entry.itemId) } label: {
            Group {
                if style == .landscape {
                    VStack(alignment: .leading, spacing: 0) {
                        WeekStill(entry: entry, overlay: entry.airTime())
                        VStack(alignment: .leading, spacing: 5) {
                            Text(entry.title).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(1)
                            WeekCardSub(entry: entry, leadingGlyph: false)
                            CalRailWrap(entry: entry, now: now, outlined: false, metaSize: 10, rowGap: 8, columnGap: 16)
                                .padding(.top, 9)
                        }
                        .padding(.top, 10)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top, spacing: 12) {
                            WeekPoster(entry: entry, style: style)
                            VStack(alignment: .leading, spacing: 2) {
                                if let time = style == .compact ? entry.airStart() : entry.airTime() {
                                    Text(time)
                                        .font(style == .compact
                                              ? .system(size: 9, weight: .semibold, design: .monospaced)
                                              : .system(size: 11, weight: .semibold).monospacedDigit())
                                        .foregroundStyle(style == .accent ? entry.accentTier.color : Theme.grab)
                                }
                                Text(entry.title).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(2)
                                WeekCardSub(entry: entry, leadingGlyph: style == .portrait)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        CalRailWrap(entry: entry, now: now, outlined: false, metaSize: 10, rowGap: 8, columnGap: 16)
                            .padding(.top, 9)
                    }
                    .padding(12)
                }
            }
            .modifier(WeekCardChrome(style: style, tier: entry.accentTier, aired: entry.hasAired(now: now), live: entry.isGrabbing))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.title) · \(entry.label)\(entry.airTime().map { " · \($0)" } ?? "")")
    }
}

private struct SeasonDropCard: View {
    @Environment(AppModel.self) private var model
    let group: SeasonGroup
    let style: WeekCardStyle
    let now: Date

    var body: some View {
        let entry = group.item
        let count = group.entries.count
        let timed = group.entries.contains { $0.airDatetime != nil }
        let overlay = timed ? (entry.airTime() ?? "Season") : "Season · all day"
        let season = entry.seasonNumber.map { "Season \($0)" } ?? "Season"
        Button { model.open(entry.itemId) } label: {
            Group {
                if style == .landscape {
                    VStack(alignment: .leading, spacing: 0) {
                        WeekStill(entry: entry, overlay: overlay)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(entry.title).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(1)
                            HStack(spacing: 6) {
                                Text(season).fontWeight(.bold).foregroundStyle(Theme.txt)
                                Text("\(count) episodes · season drop").foregroundStyle(Theme.mut).lineLimit(1)
                            }
                            .font(.system(size: 12))
                            seasonRails.padding(.top, 9)
                        }
                        .padding(.top, 10)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top, spacing: 12) {
                            WeekPoster(entry: entry, style: style)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("◈ SEASON DROP")
                                    .font(.system(size: 7.5, weight: .heavy))
                                    .tracking(0.45)
                                    .foregroundStyle(Theme.cyan)
                                Text(overlay)
                                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(style == .accent ? entry.accentTier.color : Theme.grab)
                                Text(entry.title).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(2)
                                HStack(spacing: 5) {
                                    if style == .portrait {
                                        LineGlyph(kind: LineGlyph.kind(for: entry), size: 13)
                                    }
                                    Text("\(season) · \(count) episodes")
                                }
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.mut)
                                .padding(.top, 2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        seasonRails.padding(.top, 9)
                    }
                    .padding(12)
                }
            }
            .modifier(WeekCardChrome(style: style, tier: entry.accentTier, aired: false, live: false))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.title) · \(season) · \(count) episodes · season drop · \(overlay)")
    }

    private var seasonRails: some View {
        CalFlow(spacing: 16, lineSpacing: 8) {
            ForEach(Array(group.tiers.enumerated()), id: \.offset) { _, tier in
                CalRail(rail: CalRailModel(season: tier), outlinedTier: false, metaSize: 10)
            }
        }
    }
}

/// The landscape still: backdrop → poster → gradient, 108pt tall, air window bottom-left.
private struct WeekStill: View {
    let entry: CalendarEntry
    let overlay: String?

    var body: some View {
        let src = entry.backdropUrl ?? entry.posterUrl
        PosterImage(url: TMDBImage.resized(src, to: entry.backdropUrl != nil ? "w780" : "w342"))
            .frame(maxWidth: .infinity)
            .frame(height: 108)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                if let overlay {
                    Text(overlay)
                        .font(.system(size: 9, weight: .bold).monospacedDigit())
                        .foregroundStyle(Color(hex: 0xEEF3F9))
                        .shadow(color: .black, radius: 1.5, y: 1)
                        .padding(.leading, 5)
                        .padding(.bottom, 4)
                }
            }
    }
}

/// The portrait / compact / accent poster (poster → backdrop → gradient).
private struct WeekPoster: View {
    let entry: CalendarEntry
    let style: WeekCardStyle

    private var size: CGSize {
        switch style {
        case .portrait: return CGSize(width: 48, height: 72)
        case .compact: return CGSize(width: 18, height: 27)
        default: return CGSize(width: 24, height: 36)
        }
    }

    var body: some View {
        PosterImage(url: TMDBImage.resized(entry.posterUrl ?? entry.backdropUrl, to: "w154"))
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: style == .portrait ? 5 : 3, style: .continuous))
    }
}

/// Code · `#N · Anime` · episode name.
private struct WeekCardSub: View {
    let entry: CalendarEntry
    let leadingGlyph: Bool

    var body: some View {
        HStack(spacing: 6) {
            if leadingGlyph {
                LineGlyph(kind: LineGlyph.kind(for: entry), size: 13).foregroundStyle(Theme.mut)
            }
            Text(entry.code).fontWeight(.bold).foregroundStyle(Theme.txt).monospacedDigit()
            if entry.isAnime, let abs = entry.absoluteNumber {
                Text("#\(abs) · Anime").fontWeight(.heavy).foregroundStyle(Theme.anime)
            }
            if !entry.isMovie, let name = entry.episodeTitle, !name.isEmpty {
                Text(name).foregroundStyle(Theme.mut)
            }
        }
        .font(.system(size: 12))
        .lineLimit(1)
    }
}
