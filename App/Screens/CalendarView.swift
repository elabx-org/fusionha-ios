import SwiftUI
import UIKit
import FusionhaKit

/// The web's Calendar (`routes/Calendar.tsx`, mobile layout): title + counts, media
/// chips, the five views (Month · Week · Forecast · Day · Agenda), prev / Today /
/// next, the iCal feed, the status and release-type legends, then the view body.
struct CalendarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The last chosen view, remembered per device (web `fusionha.calendar.view`).
    @AppStorage("calendar.view") private var storedView = ""
    /// A view switched to without choosing it (tapping a month day opens Day).
    @State private var sessionView: CalendarViewMode?

    @State private var settings: AppSettings?
    @State private var settingsResolved = false
    @State private var monthAnchor = Date()
    @State private var weekAnchor = Date()
    @State private var dayAnchor = Date()
    @State private var filter: CalendarMediaFilter = .all
    @State private var feed: [CalendarEntry] = []
    @State private var phase: LoadPhase = .loading
    @State private var collapsed = false
    @State private var toast: CalToast?
    @State private var copyingFeed = false

    enum LoadPhase: Equatable {
        case loading, failed, loaded
    }

    private var cal: Calendar { CalendarMath.gregorian() }
    private var today: Date { Date() }
    private var todayIso: String { CalendarMath.iso(today, cal) }
    private var firstDay: Int { settings?.firstDay ?? 0 }
    private var cardStyle: WeekCardStyle { .resolve(settings?.calendarWeekCardStyle) }
    private var quipsOn: Bool { settings?.voicePlayful ?? true }
    /// Reduce Motion or the server's `animations_enabled = false`.
    private var motionOff: Bool { reduceMotion || settings?.animationsEnabled == false }

    private var view: CalendarViewMode {
        if let sessionView { return sessionView }
        return .resolve(stored: storedView.isEmpty ? nil : storedView,
                        settingDefault: settings?.calendarDefaultView)
    }

    /// The view can't be known until settings answer, unless one is remembered.
    private var viewKnown: Bool { sessionView != nil || CalendarViewMode(rawValue: storedView) != nil || settingsResolved }

    private var bounds: (start: String, end: String) {
        switch view {
        case .day:
            let iso = CalendarMath.iso(dayAnchor, cal)
            return (iso, iso)
        case .forecast:
            return (todayIso, CalendarMath.shift(todayIso, days: CalendarMath.forecastDays - 1, cal))
        case .week:
            let days = CalendarMath.weekDays(weekAnchor, firstDay: firstDay, cal)
            return (days[0], days[6])
        case .month, .agenda:
            return CalendarMath.monthBounds(monthAnchor, cal)
        }
    }

    /// The filtered feed (the chips never touch the header counts).
    private var entries: [CalendarEntry] { let f = self.filter; return feed.filter { f.matches($0) } }

    private var title: String {
        switch view {
        case .week: return CalendarMath.weekTitle(weekAnchor, firstDay: firstDay, cal)
        case .day: return CalendarMath.dayTitle(dayAnchor, cal)
        case .forecast: return CalendarMath.forecastTitle(today, cal)
        case .month, .agenda: return CalendarMath.monthTitle(monthAnchor, cal)
        }
    }

    private var subline: String {
        let (start, end) = bounds
        let total = feed.filter { let d = $0.localDay(cal); return d >= start && d <= end }.count
        let todayCount = feed.filter { $0.localDay(cal) == todayIso }.count
        return "\(total) scheduled · \(todayCount) today"
    }

    private var fetchKey: String {
        viewKnown ? "\(bounds.start)|\(bounds.end)|\(model.credentials?.serverURL.absoluteString ?? "")" : "pending"
    }

    var body: some View {
        Screen {
            Group {
                if view == .week {
                    weekLayout
                } else {
                    scrollLayout
                }
            }
        }
        .calToast($toast)
        .environment(\.calMotionOff, settings?.animationsEnabled == false)
        .task { await loadSettings() }
        .task(id: fetchKey) { await load() }
        .onAppear(perform: applyScreenshotView)
    }

    // MARK: Layouts

    private var scrollLayout: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    toolbar
                        .padding(.bottom, 16)
                    content
                        .id("\(view)|\(bounds.start)|\(phase)")
                        .transition(.opacity)
                }
                .animation(motionOff ? nil : .easeOut(duration: 0.2), value: "\(view)|\(bounds.start)|\(phase)")
                .padding(.top, 20)
                .padding(.horizontal, 10)
                .padding(.bottom, 24)
            }
            .refreshable { await load() }
            .task(id: "\(view)|\(phase)|\(entries.count)") {
                guard phase == .loaded, view == .agenda || view == .forecast || view == .day else { return }
                try? await Task.sleep(for: .milliseconds(60))
                proxy.scrollTo("day-\(todayIso)", anchor: .top)
            }
        }
    }

    private var weekLayout: some View {
        VStack(spacing: 0) {
            if !collapsed {
                toolbar
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            if phase == .loaded {
                WeekMobileView(
                    days: CalendarMath.weekDays(weekAnchor, firstDay: firstDay, cal),
                    entries: entries,
                    todayIso: todayIso,
                    cardStyle: cardStyle,
                    collapsed: $collapsed,
                    title: title,
                    onPrev: { step(-1) },
                    onToday: goToday,
                    onNext: { step(1) })
            } else {
                content.padding(.horizontal, 10)
                Spacer(minLength: 0)
            }
        }
        .padding(.top, 12)
        .clipped()
        .animation(motionOff ? nil : .timingCurve(0.4, 0, 0.2, 1, duration: 0.32), value: collapsed)
        .onChange(of: view) { collapsed = false }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            CalEmptyState(message: "Loading the calendar…")
        case .failed:
            CalEmptyState(message: "The calendar could not be loaded. Check the backend and try again.")
        case .loaded:
            switch view {
            case .month:
                MonthGridView(month: monthAnchor, entries: entries, todayIso: todayIso, firstDay: firstDay) { iso in
                    if let date = CalendarMath.date(iso, cal) {
                        dayAnchor = date
                        withAnimation(.snappy) { sessionView = .day }
                    }
                }
            case .agenda:
                groupedList(
                    "Nothing is scheduled this month. Aired episodes and movie releases show up here as your monitored titles hit their dates.",
                    quip: "Right where I expected it.")
            case .forecast:
                groupedList(
                    "Nothing airs in the next \(CalendarMath.forecastDays) days. Upcoming episodes and movie releases show up here as their dates approach.",
                    quip: "Right where I expected it.")
            case .day:
                groupedList(
                    "Nothing airs on \(CalendarMath.dayTitle(dayAnchor, cal)). Pick another day or switch views to see what's scheduled.",
                    quip: "Winter came early — and it brought loot.")
            case .week:
                EmptyView()
            }
        }
    }

    private func groupedList(_ empty: String, quip: String) -> some View {
        let (start, end) = bounds
        let visible = entries.filter { let d = $0.localDay(cal); return d >= start && d <= end }
        return GroupedDayList(entries: visible, todayIso: todayIso, emptyMessage: empty, quip: quipsOn ? quip : nil)
    }

    // MARK: Toolbar

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 20, weight: .heavy))
                    .tracking(-0.2)
                    .foregroundStyle(Theme.txt)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subline)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.mut)
            }
            filterChips
            viewPicker
            navRow
            VStack(alignment: .leading, spacing: 12) {
                statusLegend
                releaseLegend
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filterChips: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(CalendarMediaFilter.allCases, id: \.self) { value in
                    let on = filter == value
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { filter = value }
                    } label: {
                        Text(value.label)
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(on ? Theme.txt : Theme.mut)
                            .padding(.horizontal, 11)
                            .frame(height: 28)
                            .glassEffect(on ? .regular.tint(Theme.indigo.opacity(0.12)).interactive() : .regular.interactive(),
                                         in: Capsule())
                            .overlay(Capsule().strokeBorder(on ? Theme.indigo.opacity(0.58) : Theme.line))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
        .sensoryFeedback(.selection, trigger: filter)
    }

    private var viewPicker: some View {
        HStack(spacing: 2) {
            ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                let on = view == mode
                Button {
                    setView(mode)
                } label: {
                    Text(mode.label)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(on ? Theme.txt : Theme.mut)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background {
                            if on {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Theme.card)
                                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .glassEffect(.regular.tint(Theme.mut.opacity(0.12)), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .sensoryFeedback(.selection, trigger: view)
    }

    private var stepNoun: String {
        switch view {
        case .week: return "week"
        case .day: return "day"
        default: return "month"
        }
    }

    private var navRow: some View {
        HStack(spacing: 6) {
            if view != .forecast {
                CalNavButtons(noun: stepNoun, onPrev: { step(-1) }, onToday: goToday, onNext: { step(1) })
            }
            if model.me?.isAdmin == true {
                icalMenu
            }
            if view == .week {
                weekStyleMenu
            }
        }
    }

    private var icalMenu: some View {
        Menu {
            Button("Copy feed URL", systemImage: "doc.on.doc") { Task { await feedURL(subscribe: false) } }
            Button("Subscribe in Calendar", systemImage: "calendar.badge.plus") { Task { await feedURL(subscribe: true) } }
        } label: {
            HStack(spacing: 7) {
                LineGlyph(kind: .feed, size: 15)
                Text("iCal feed")
            }
        }
        .buttonStyle(CalButtonStyle(variant: .ghost))
        .disabled(copyingFeed)
        .accessibilityLabel("Copy iCal feed URL")
    }

    private var weekStyleMenu: some View {
        Menu {
            Section("Week card style") {
                ForEach(WeekCardStyle.allCases, id: \.self) { style in
                    Button {
                        setCardStyle(style)
                    } label: {
                        if style == cardStyle {
                            Label(style.label, systemImage: "checkmark")
                        } else {
                            Text(style.label)
                        }
                        Text(style.detail)
                    }
                }
            }
        } label: {
            Image(systemName: "gearshape").font(.system(size: 14, weight: .medium))
        }
        .buttonStyle(CalButtonStyle(variant: .ghost))
        .accessibilityLabel("Week card style")
    }

    private var statusLegend: some View {
        HStack(spacing: 12) {
            ForEach(CalendarStatusKey.allCases, id: \.self) { key in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 3).fill(key.color).frame(width: 9, height: 9)
                    Text(key.label)
                }
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(Theme.mut)
        .lineLimit(1)
    }

    private var releaseLegend: some View {
        HStack(spacing: 12) {
            ForEach(MovieReleaseType.allCases, id: \.self) { type in
                HStack(spacing: 5) {
                    Image(systemName: type.symbol)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(type.color)
                        .frame(width: 15, height: 15)
                    Text(type.label)
                }
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(Theme.mut)
        .lineLimit(1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Movie release types: Theatrical, Digital, Physical")
    }

    // MARK: Actions

    private func setView(_ mode: CalendarViewMode) {
        storedView = mode.rawValue
        withAnimation(.snappy(duration: 0.25)) { sessionView = mode }
    }

    private func step(_ direction: Int) {
        withAnimation(.snappy) {
            switch view {
            case .week: weekAnchor = CalendarMath.addDays(weekAnchor, 7 * direction, cal)
            case .day: dayAnchor = CalendarMath.addDays(dayAnchor, direction, cal)
            default: monthAnchor = CalendarMath.addMonths(monthAnchor, direction, cal)
            }
        }
    }

    private func goToday() {
        withAnimation(.snappy) {
            switch view {
            case .week: weekAnchor = Date()
            case .day: dayAnchor = Date()
            default: monthAnchor = Date()
            }
        }
    }

    private func setCardStyle(_ style: WeekCardStyle) {
        let previous = settings
        settings = AppSettings(firstDayOfWeek: settings?.firstDayOfWeek,
                               calendarDefaultView: settings?.calendarDefaultView,
                               calendarWeekCardStyle: style.rawValue,
                               voicePlayful: settings?.voicePlayful,
                               animationsEnabled: settings?.animationsEnabled)
        Task {
            do {
                try await model.client?.setWeekCardStyle(style)
            } catch {
                settings = previous
                toast = CalToast(message: "The week card style could not be saved.", isError: true)
            }
        }
    }

    /// Reveal the app API key, build `…/api/v1/calendar/feed.ics?apikey=` and copy
    /// it (or hand its `webcal://` form to the Calendar app).
    private func feedURL(subscribe: Bool) async {
        guard let client = model.client else { return }
        copyingFeed = true
        defer { copyingFeed = false }
        do {
            let key = try await client.appApiKey()
            guard let url = client.calendarFeedURL(apiKey: key) else { throw APIError.invalidServerURL }
            if subscribe, var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                parts.scheme = "webcal"
                if let webcal = parts.url { _ = await UIApplication.shared.open(webcal) }
            } else {
                UIPasteboard.general.string = url.absoluteString
                toast = CalToast(message: "iCal feed URL copied — paste it into your calendar app.")
            }
        } catch {
            toast = CalToast(message: "The iCal feed URL could not be copied.", isError: true)
        }
    }

    // MARK: Loading

    private func loadSettings() async {
        guard let client = model.client else { return }
        if let loaded = try? await client.settings() { settings = loaded }
        settingsResolved = true
    }

    private func load() async {
        guard viewKnown, let client = model.client else { return }
        let (start, end) = bounds
        if feed.isEmpty { phase = .loading }
        do {
            // ±1 day: entries sit on their LOCAL air day, which can be a day off TMDB's date.
            feed = try await client.calendar(startISO: CalendarMath.shift(start, days: -1, cal),
                                             endISO: CalendarMath.shift(end, days: 1, cal))
            phase = .loaded
        } catch is CancellationError {
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            phase = .failed
        }
    }

    private func applyScreenshotView() {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_CALENDAR_VIEW"],
           let mode = CalendarViewMode(rawValue: raw) {
            sessionView = mode
        }
        #endif
    }
}

/// ‹ · Today · › (ghost / subtle `sm` buttons).
struct CalNavButtons: View {
    let noun: String
    let onPrev: () -> Void
    let onToday: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onPrev) {
                Image(systemName: "chevron.left").font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(CalButtonStyle(variant: .ghost))
            .accessibilityLabel("Previous \(noun)")
            Button("Today", action: onToday)
                .buttonStyle(CalButtonStyle(variant: .subtle))
            Button(action: onNext) {
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(CalButtonStyle(variant: .ghost))
            .accessibilityLabel("Next \(noun)")
        }
    }
}

// MARK: - Month

/// `MonthView`: weekday header, rounded day cells with up to two event pills and
/// `+N more`. Tapping a cell's empty space opens that day in the Day view.
private struct MonthGridView: View {
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
                    Text(day.uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.8)
                        .foregroundStyle(Theme.mut)
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
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return VStack(alignment: .leading, spacing: 4) {
            Text(iso.suffix(2).hasPrefix("0") ? String(iso.suffix(1)) : String(iso.suffix(2)))
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(isToday ? Theme.grab : Theme.mut)
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
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(Theme.mut)
                    .padding(.leading, 4)
                    .lineLimit(1)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
        .background(weekend ? Theme.indigo.opacity(0.05) : Theme.card.opacity(0.6), in: shape)
        .overlay {
            if isToday {
                shape.strokeBorder(Theme.grab.opacity(0.55))
                shape.inset(by: 1).strokeBorder(Theme.grab.opacity(0.3))
            } else {
                shape.strokeBorder(Theme.line)
            }
        }
        .clipShape(shape)
        .contentShape(shape)
        .onTapGesture { openDay(iso) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(CalendarMath.agendaDayLabel(iso, cal))\(isToday ? ", Today" : ""), \(items.count) scheduled")
        .accessibilityAction(named: "Open day") { openDay(iso) }
    }
}

/// `.mev`: kind strip, title (collapses first), code, up to three edition dots.
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
                .font(.system(size: 10, weight: .bold))
                .lineLimit(1)
                .fixedSize()
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
        .calLivePulse(entry.isGrabbing, shape: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.title) · \(entry.label)")
    }
}

// MARK: - Agenda / Forecast / Day

/// `GroupedDayList`: a 92pt date rail per day, a timeline line, the "now" marker in
/// today's group, and one row per entry. Only days with entries are listed.
struct GroupedDayList: View {
    let entries: [CalendarEntry]
    let todayIso: String
    let emptyMessage: String
    let quip: String?

    private var cal: Calendar { CalendarMath.gregorian() }

    var body: some View {
        if entries.isEmpty {
            CalEmptyState(message: emptyMessage, quip: quip)
        } else {
            let byDay = CalendarMath.groupByDay(entries, cal)
            let dayIndex = Dictionary(uniqueKeysWithValues: byDay.keys.sorted().enumerated().map { ($0.element, $0.offset) })
            let now = Date()
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(byDay.keys.sorted(), id: \.self) { iso in
                    DayGroup(iso: iso, entries: byDay[iso] ?? [], isToday: iso == todayIso, now: now)
                        .calReveal(dayIndex[iso] ?? 0, stagger: 0.04)
                        .id("day-\(iso)")
                }
            }
        }
    }
}

private struct DayGroup: View {
    let iso: String
    let entries: [CalendarEntry]
    let isToday: Bool
    let now: Date

    private var cal: Calendar { CalendarMath.gregorian() }

    var body: some View {
        let nowIndex: Int? = isToday ? entries.firstIndex(where: { !$0.hasAired(now: now) }) : nil
        HStack(alignment: .top, spacing: 0) {
            rail
                .frame(width: 92, alignment: .trailing)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                    if index == nowIndex {
                        NowMarker(now: now)
                    }
                    AgendaRow(entry: entry, now: now)
                        .padding(.bottom, 9)
                }
            }
            .padding(.leading, 20)
            .padding(.bottom, 26)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(isToday ? Theme.grab.opacity(0.45) : Theme.line)
                    .frame(width: 1)
            }
        }
    }

    private var rail: some View {
        let weekday = CalendarMath.weekday(iso: iso, cal)
        let day = Int(iso.suffix(2)) ?? 0
        return VStack(alignment: .trailing, spacing: 0) {
            Text(CalendarMath.dow[weekday].uppercased())
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.88)
                .foregroundStyle(Theme.mut)
            Text("\(day)")
                .font(.system(size: 24, weight: .heavy))
                .tracking(-0.48)
                .foregroundStyle(isToday ? AnyShapeStyle(Theme.fusion) : AnyShapeStyle(Theme.txt))
                .padding(.top, 2)
            if isToday {
                Text("TODAY")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.9)
                    .foregroundStyle(Color(hex: 0x04121A))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Theme.grab, in: Capsule())
                    .padding(.top, 6)
            }
            Text("\(entries.count) event\(entries.count == 1 ? "" : "s")")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.mut)
                .padding(.top, 6)
        }
        .padding(.top, 2)
        .padding(.trailing, 14)
        .padding(.bottom, 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(CalendarMath.agendaDayLabel(iso, cal))\(isToday ? ", Today" : "")")
    }
}

/// The live "now" line: a cyan dot on the timeline with `now 9:12 PM`.
private struct NowMarker: View {
    let now: Date

    var body: some View {
        TimelineView(.everyMinute) { context in
            marker(context.date)
        }
        .frame(height: 0)
        .padding(.top, 6)
        .padding(.bottom, 14)
    }

    private func marker(_ now: Date) -> some View {
        ZStack(alignment: .leading) {
            Circle()
                .fill(Theme.grab)
                .frame(width: 9, height: 9)
                .background(Circle().fill(Theme.grab.opacity(0.25)).frame(width: 15, height: 15))
                .offset(x: -24.5)
            Text("now \(CalendarMath.clock(now))")
                .font(.system(size: 9.5, weight: .heavy))
                .tracking(0.48)
                .foregroundStyle(Theme.grab)
                .lineLimit(1)
                .fixedSize()
                .offset(x: -4, y: -9)
        }
        .accessibilityLabel("Now, \(CalendarMath.clock(now))")
    }
}

/// `AgendaRow`: 46×66 poster, air time, title, sub line, then one rail per edition.
private struct AgendaRow: View {
    @Environment(AppModel.self) private var model
    let entry: CalendarEntry
    let now: Date

    var body: some View {
        Button { model.open(entry.itemId) } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 10) {
                    PosterImage(url: TMDBImage.resized(entry.posterUrl, to: "w154"))
                        .frame(width: 46, height: 66)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    VStack(alignment: .leading, spacing: 0) {
                        if !entry.isMovie, let time = entry.airTime() {
                            Text(time)
                                .font(.system(size: 11, weight: .bold).monospacedDigit())
                                .tracking(-0.11)
                                .foregroundStyle(Theme.grab)
                                .lineLimit(1)
                        }
                        Text(entry.title)
                            .font(.system(size: 13.5, weight: .bold))
                            .tracking(-0.135)
                            .foregroundStyle(Theme.txt)
                            .lineLimit(1)
                            .padding(.top, 1)
                        sub.padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                CalRailWrap(entry: entry, now: now, outlined: true, metaSize: 9, rowGap: 7, columnGap: 14)
                    .padding(.top, 20)
            }
            .padding(.top, 9)
            .padding(.trailing, 12)
            .padding(.bottom, 9)
            .padding(.leading, 9)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line))
            .opacity(entry.hasAired(now: now) ? 0.62 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var sub: some View {
        CalFlow(spacing: 7, lineSpacing: 4) {
            LineGlyph(kind: LineGlyph.kind(for: entry), size: 13)
                .foregroundStyle(Theme.mut)
                .accessibilityLabel(entry.isAnime ? "Anime" : (entry.isMovie ? "Movie" : "Series"))
            if entry.isMovie {
                if let type = entry.movieReleaseType {
                    Text(type.label.uppercased())
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.36)
                        .foregroundStyle(type.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(type.color.opacity(0.4)))
                } else {
                    Text(entry.label).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.txt)
                }
            } else {
                Text(entry.code).font(.system(size: 11, weight: .bold).monospacedDigit()).foregroundStyle(Theme.txt)
            }
            if entry.isAnime {
                Text(entry.absoluteNumber.map { "#\($0) · Anime" } ?? "Anime")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Theme.anime)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(Theme.anime.opacity(0.16), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            if let name = entry.episodeTitle, !name.isEmpty {
                Text(name).font(.system(size: 11)).foregroundStyle(Theme.mut).lineLimit(1)
            }
        }
    }
}

/// One rail per edition in a wrapping row (HD and 4K side by side).
struct CalRailWrap: View {
    let entry: CalendarEntry
    let now: Date
    var outlined = true
    var metaSize: CGFloat = 9
    var rowGap: CGFloat = 7
    var columnGap: CGFloat = 14

    var body: some View {
        CalFlow(spacing: columnGap, lineSpacing: rowGap) {
            ForEach(Array(entry.editions.enumerated()), id: \.offset) { _, edition in
                CalRail(rail: CalRailModel(entry: entry, edition: edition, now: now),
                        outlinedTier: outlined, metaSize: metaSize)
            }
        }
    }
}

/// A wrapping row (CSS `flex-wrap: wrap`) with centred items per line.
struct CalFlow: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0 && x + size.width > width {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: min(maxX, width), height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var lines: [[(LayoutSubview, CGSize)]] = [[]]
        var x: CGFloat = 0
        for view in subviews {
            var size = view.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            size.width = min(size.width, bounds.width)
            if x > 0 && x + size.width > bounds.width {
                lines.append([])
                x = 0
            }
            lines[lines.count - 1].append((view, size))
            x += size.width + spacing
        }
        var y = bounds.minY
        for line in lines {
            let height = line.map { $0.1.height }.max() ?? 0
            var lx = bounds.minX
            for (view, size) in line {
                view.place(at: CGPoint(x: lx, y: y + (height - size.height) / 2),
                           proposal: ProposedViewSize(width: size.width, height: size.height))
                lx += size.width + spacing
            }
            y += height + lineSpacing
        }
    }
}
