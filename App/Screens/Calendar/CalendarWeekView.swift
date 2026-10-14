import SwiftUI
import FusionhaKit

/// The web's mobile Week (`WeekMobile`): a pinned header (slim bar once the toolbar
/// has folded away, then the seven-day strip) over an agenda of all seven days,
/// which is the only scroller. Season drops (≥ 3 same-day episodes) collapse into
/// one card. Day groups live in `CalendarWeekDayGroup`, cards in `CalendarWeekCards`.
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
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(days.enumerated()), id: \.element) { index, iso in
                            WeekDayGroup(iso: iso, entries: byDay[iso] ?? [], isToday: iso == todayIso, style: cardStyle)
                                .calReveal(index, stagger: 0.02)
                                .id("week-\(iso)")
                        }
                    }
                    .padding(.horizontal, Theme.pageGutter)
                    .padding(.top, 2)
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
                        .font(Theme.display(26, relativeTo: .title2))
                        .tracking(Theme.displayTracking(26))
                        .foregroundStyle(Theme.txt)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    CalNavButtons(noun: "week", onPrev: onPrev, onToday: onToday, onNext: onNext)
                }
                .padding(.top, 8)
                .padding(.horizontal, Theme.pageGutter)
                .transition(animated ? .opacity.combined(with: .offset(y: -4)).animation(.easeOut(duration: 0.2)) : .identity)
            }
            HStack(spacing: 4) {
                ForEach(days, id: \.self) { iso in
                    CalWeekDayChip(iso: iso, entries: byDay[iso] ?? [], isToday: iso == todayIso, on: activeDay == iso) {
                        selected = iso
                        if animated {
                            withAnimation(.smooth) { proxy.scrollTo("week-\(iso)", anchor: .top) }
                        } else {
                            proxy.scrollTo("week-\(iso)", anchor: .top)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .sensoryFeedback(.selection, trigger: activeDay)
        }
        .background(Theme.bg)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}

/// One day of the strip (`.week .d`): weekday, the date, the day's status dots.
/// The active day is lit cream with dark text; today, when another day is
/// active, keeps a cream hairline.
private struct CalWeekDayChip: View {
    let iso: String
    let entries: [CalendarEntry]
    let isToday: Bool
    let on: Bool
    let action: () -> Void

    private var cal: Calendar { CalendarMath.gregorian() }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        Button(action: action) {
            VStack(spacing: 4) {
                Text(CalendarMath.dow[CalendarMath.weekday(iso: iso, cal)])
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(on ? Color(hex: 0x5A4F43) : Theme.dim)
                Text("\(Int(iso.suffix(2)) ?? 0)")
                    .font(.system(size: 20, weight: .semibold).monospacedDigit())
                    .foregroundStyle(on ? Theme.onPrimary : Theme.txt)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 3) {
                    ForEach(CalendarEntry.statusKeys(entries), id: \.self) { key in
                        Circle().fill(key.color).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                if on { shape.fill(Theme.txt) }
            }
            .overlay {
                if isToday && !on { shape.strokeBorder(Theme.txt.opacity(0.35), lineWidth: 1) }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(CalendarMath.weekDayLabel(iso, cal))\(isToday ? ", Today" : "")")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
