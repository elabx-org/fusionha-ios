import SwiftUI
import FusionhaKit

/// The web's Calendar (`routes/Calendar.tsx`, mobile layout): title + counts, the
/// five views (Month · Week · Forecast · Day · Agenda), prev / Today / next with the
/// kind chips and the iCal feed, the status and release-type legends, then the view
/// body. The toolbar lives in `CalendarView+Toolbar`, actions and loading in
/// `CalendarView+Actions`.
struct CalendarView: View {
    @Environment(AppModel.self) var model
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.horizontalSizeClass) var sizeClass
    /// The last chosen view, remembered per device (web `fusionha.calendar.view`).
    @AppStorage("calendar.view") var storedView = ""
    /// A view switched to without choosing it (tapping a month day opens Day).
    @State var sessionView: CalendarViewMode?

    @State var settings: AppSettings?
    @State var settingsResolved = false
    @State var monthAnchor = Date()
    @State var weekAnchor = Date()
    @State var dayAnchor = Date()
    @State var filter: CalendarMediaFilter = .all
    @State var feed: [CalendarEntry] = []
    @State var phase: LoadPhase = .loading
    @State var collapsed = false
    @State var copyingFeed = false
    /// Bumped to bring the view back to today (Today, the tab, a re-tap).
    @State var todayTick = 0
    /// Bumped by a period swipe (haptic).
    @State var swipeTick = 0
    /// Week and the Month day panel use the web's phone cards unless one of the
    /// four server card styles was picked (a recorded iOS extra, L11).
    @AppStorage("calendar.phoneCards") var phoneCards = true

    enum LoadPhase: Equatable {
        case loading, failed, loaded
    }

    var cal: Calendar { CalendarMath.gregorian() }
    var today: Date { Date() }
    var todayIso: String { CalendarMath.iso(today, cal) }
    var firstDay: Int { settings?.firstDay ?? 0 }
    var cardStyle: WeekCardStyle { .resolve(settings?.calendarWeekCardStyle) }
    /// nil = the web's phone cards.
    var weekCards: WeekCardStyle? { phoneCards ? nil : cardStyle }
    var isPhone: Bool { sizeClass != .regular }
    var quipsOn: Bool { settings?.voicePlayful ?? true }
    /// Reduce Motion or the server's `animations_enabled = false`.
    var motionOff: Bool { reduceMotion || settings?.animationsEnabled == false }

    var view: CalendarViewMode {
        if let sessionView { return sessionView }
        return .resolve(stored: storedView.isEmpty ? nil : storedView,
                        settingDefault: settings?.calendarDefaultView)
    }

    /// The view can't be known until settings answer, unless one is remembered.
    var viewKnown: Bool { sessionView != nil || CalendarViewMode(rawValue: storedView) != nil || settingsResolved }

    var bounds: (start: String, end: String) {
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
    var entries: [CalendarEntry] { let f = self.filter; return feed.filter { f.matches($0) } }

    var title: String {
        switch view {
        case .week: return CalendarMath.weekTitle(weekAnchor, firstDay: firstDay, cal)
        case .day: return CalendarMath.dayTitle(dayAnchor, cal)
        case .forecast: return CalendarMath.forecastTitle(today, cal)
        case .month, .agenda: return CalendarMath.monthTitle(monthAnchor, cal)
        }
    }

    var subline: String {
        let (start, end) = bounds
        let total = feed.filter { let d = $0.localDay(cal); return d >= start && d <= end }.count
        let todayCount = feed.filter { $0.localDay(cal) == todayIso }.count
        return "\(total) scheduled · \(todayCount) today"
    }

    var fetchKey: String {
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
        .shellPage(title)
        .toolbar { barItems }
        .environment(\.calMotionOff, settings?.animationsEnabled == false)
        .task { await loadSettings() }
        .onChange(of: model.calendarTodayTick) { goToday() }
        .task(id: fetchKey) { await load() }
        .onAppear(perform: applyScreenshotView)
        .sensoryFeedback(.selection, trigger: swipeTick)
    }

    /// The phone header (web `CalendarHeaderMobile`), else the wide toolbar.
    @ViewBuilder
    var header: some View {
        if isPhone { phoneToolbar } else { toolbar }
    }

    // MARK: Layouts

    private var scrollLayout: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.bottom, 8)
                    content
                        .id("\(view)|\(bounds.start)|\(phase)")
                        .transition(.opacity)
                        .gesture(periodSwipe)
                }
                .animation(motionOff ? nil : .easeOut(duration: 0.2), value: "\(view)|\(bounds.start)|\(phase)")
                .padding(.top, 20)
                .padding(.horizontal, Theme.pageGutter)
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
                header
                    .padding(.horizontal, Theme.pageGutter)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            if phase == .loaded {
                WeekMobileView(
                    days: CalendarMath.weekDays(weekAnchor, firstDay: firstDay, cal),
                    entries: entries,
                    todayIso: todayIso,
                    todayTick: todayTick,
                    cards: weekCards,
                    swipe: periodSwipe,
                    collapsed: $collapsed,
                    title: title,
                    onPrev: { step(-1) },
                    onToday: goToday,
                    onNext: { step(1) })
            } else {
                content.padding(.horizontal, Theme.pageGutter).padding(.top, 12)
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
                .padding(.top, 12)
        case .failed:
            CalEmptyState(message: "The calendar could not be loaded. Check the backend and try again.")
                .padding(.top, 12)
        case .loaded:
            loadedContent
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        switch view {
        case .month where sizeClass == .regular:
            // iPad width: the full grid with event pills.
            MonthGridView(month: monthAnchor, entries: entries, todayIso: todayIso, firstDay: firstDay) { iso in
                if let date = CalendarMath.date(iso, cal) {
                    dayAnchor = date
                    withAnimation(motionOff ? nil : .snappy) { sessionView = .day }
                }
            }
            .padding(.top, 12)
        case .month:
            // Phone: dots and counts in the grid, the picked day listed below (web `MonthMobile`).
            MonthMobileView(month: monthAnchor, entries: entries, todayIso: todayIso, firstDay: firstDay,
                            cards: weekCards, todayTick: todayTick)
                .padding(.top, 8)
        case .agenda where isPhone:
            phoneList(.agenda)
        case .forecast where isPhone:
            phoneList(.forecast)
        case .day where isPhone:
            phoneList(.day)
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

    /// Forecast / Day / Agenda on a phone (web `MobileDayList`).
    private func phoneList(_ kind: PhoneDayList.Kind) -> some View {
        let (start, end) = bounds
        return PhoneDayList(kind: kind, days: CalendarMath.isoDays(from: start, to: end, cal), entries: entries,
                            todayIso: todayIso, firstDay: firstDay) { iso in
            if let date = CalendarMath.date(iso, cal) {
                withAnimation(motionOff ? nil : .snappy) { dayAnchor = date }
            }
        }
    }

    private func groupedList(_ empty: String, quip: String) -> some View {
        let (start, end) = bounds
        let visible = entries.filter { let d = $0.localDay(cal); return d >= start && d <= end }
        return GroupedDayList(entries: visible, todayIso: todayIso, emptyMessage: empty, quip: quipsOn ? quip : nil)
    }
}
