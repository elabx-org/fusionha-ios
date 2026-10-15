import SwiftUI
import UIKit
import FusionhaKit

// Calendar actions (view switching, paging, the week card style, the iCal feed)
// and loading.
extension CalendarView {
    func setView(_ mode: CalendarViewMode) {
        storedView = mode.rawValue
        withAnimation(motionOff ? nil : .snappy(duration: 0.25)) { sessionView = mode }
    }

    func step(_ direction: Int) {
        withAnimation(motionOff ? nil : .snappy) {
            switch view {
            case .week: weekAnchor = CalendarMath.addDays(weekAnchor, 7 * direction, cal)
            case .day: dayAnchor = CalendarMath.addDays(dayAnchor, direction, cal)
            default: monthAnchor = CalendarMath.addMonths(monthAnchor, direction, cal)
            }
        }
    }

    func goToday() {
        todayTick += 1
        withAnimation(motionOff ? nil : .snappy) {
            switch view {
            case .week: weekAnchor = Date()
            case .day: dayAnchor = Date()
            default: monthAnchor = Date()
            }
        }
    }

    func setCardStyle(_ style: WeekCardStyle) {
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
    func feedURL(subscribe: Bool) async {
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

    func loadSettings() async {
        guard let client = model.client else { return }
        if let loaded = try? await client.appSettings() { settings = loaded }
        settingsResolved = true
    }

    func load() async {
        guard viewKnown, let client = model.client else { return }
        let (start, end) = bounds
        // ±1 day: entries sit on their LOCAL air day, which can be a day off TMDB's date.
        let from = CalendarMath.shift(start, days: -1, cal), to = CalendarMath.shift(end, days: 1, cal)
        if feed.isEmpty {
            // This range as this phone last saw it, at once; the server's answer replaces it.
            if let kept = await client.cached({ try await $0.calendar(startISO: from, endISO: to) }), !kept.isEmpty {
                feed = kept
                phase = .loaded
            } else {
                phase = .loading
            }
        }
        do {
            feed = try await client.calendar(startISO: from, endISO: to)
            phase = .loaded
        } catch is CancellationError {
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            phase = .failed
        }
    }

    func applyScreenshotView() {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_CALENDAR_VIEW"],
           let mode = CalendarViewMode(rawValue: raw) {
            sessionView = mode
        }
        #endif
    }
}
