import SwiftUI
import FusionhaKit

// The phone Calendar header (web `CalendarHeaderMobile` + `CalendarFilterMenu`):
// the subline beside ‹ ›, then the full-width view switch (labels shorten to
// Mo/Wk/Fc/Day/Ag when narrow). The title, Today and the filter menu are in
// the system bar (`barItems`, D1). No legends on a phone. Prev/next show only
// where a swipe also steps the period.
extension CalendarView {
    var phoneToolbar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Text(subline)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.mut)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if view.phoneSteps {
                    CalPhoneIcon(systemName: "chevron.left", label: "Previous \(view.stepNoun)") { step(-1) }
                    CalPhoneIcon(systemName: "chevron.right", label: "Next \(view.stepNoun)") { step(1) }
                }
            }
            CalViewSwitcher(selection: view, motion: !motionOff) { setView($0) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The media-type radios, then "Copy iCal feed URL" (shown as the web does).
    /// Subscribe and the week card choice are recorded iOS extras.
    var filterMenu: some View {
        Menu {
            Picker("Media type", selection: filterBinding) {
                ForEach(CalendarMediaFilter.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.inline)
            Divider()
            Button("Copy iCal feed URL", systemImage: "dot.radiowaves.up.forward") {
                Task { await feedURL(subscribe: false) }
            }
            .disabled(copyingFeed)
            Button("Subscribe in Calendar", systemImage: "calendar.badge.plus") {
                Task { await feedURL(subscribe: true) }
            }
            .disabled(copyingFeed)
            Divider()
            weekCardsMenu
        } label: {
            Label("Filter media type", systemImage: filter == .all ? "line.3.horizontal.decrease"
                                                                    : "line.3.horizontal.decrease.circle.fill")
        }
        .accessibilityValue(filter.label)
    }

    var filterBinding: Binding<CalendarMediaFilter> {
        Binding(get: { filter }, set: { value in
            withAnimation(motionOff ? nil : .snappy(duration: 0.2)) { filter = value }
        })
    }

    /// Phone cards (the web's, the default) or one of the four server card styles.
    var weekCardsMenu: some View {
        Menu("Week cards", systemImage: "rectangle.stack") {
            Picker("Week cards", selection: weekCardsBinding) {
                Text("Phone cards").tag("phone")
                ForEach(WeekCardStyle.allCases, id: \.self) { style in
                    Text(style.label).tag(style.rawValue)
                }
            }
            .pickerStyle(.inline)
        }
    }

    var weekCardsBinding: Binding<String> {
        Binding(get: { phoneCards ? "phone" : cardStyle.rawValue }, set: { value in
            if value == "phone" {
                phoneCards = true
            } else if let style = WeekCardStyle(rawValue: value) {
                phoneCards = false
                if style != cardStyle { setCardStyle(style) }
            }
        })
    }

    /// The swipe that steps the period, on the body only (never the header or a strip).
    /// `useSwipeNav`: tablet steps any view with ‹ ›, the phone its stepping
    /// views, the desktop never.
    var swipeEnabled: Bool {
        switch layout {
        case .tablet: return view != .forecast
        case .phone: return view.phoneSteps
        case .desktop: return false
        }
    }

    var periodSwipe: HorizontalPanGesture {
        HorizontalPanGesture { _ in } onEnded: { dx in
            guard swipeEnabled, let direction = CalendarSwipe.step(dx: dx, dy: 0) else { return }
            swipeTick += 1
            step(direction)
        }
    }
}

/// A 36pt round glass glyph with a 44pt hit box (`.tap44`).
struct CalPhoneIcon: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) { CalPhoneIconLabel(systemName: systemName) }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
    }
}

struct CalPhoneIconLabel: View {
    let systemName: String
    var tint: Color = Theme.txt

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            .glassEffect(.regular.interactive(), in: Circle())
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
}
