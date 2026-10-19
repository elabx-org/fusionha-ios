import SwiftUI
import FusionhaKit

// The Calendar toolbar (the mock's calendar head): the counts, the glass view
// switcher, the glass bar (‹ ›, kind chips) and the status / release legends.
// The title, Today, the iCal feed and the week card style are in the system
// bar (`barItems`, D1). Every control here is glass; nothing in it is content.
extension CalendarView {
    var toolbar: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(subline)
                .font(.system(size: 15))
                .foregroundStyle(Theme.mut)
            CalViewSwitcher(selection: view, motion: !motionOff) { setView($0) }
            calBar
            legends
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The system bar's items: Today first (it stays when the bar runs out of
    /// room); on a phone the filter menu (media type, iCal, week cards), else
    /// the iCal feed and the week card style in the overflow.
    @ToolbarContentBuilder
    var barItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Today", systemImage: "calendar.badge.clock", action: goToday)
        }
        .barPriority(true)
        if isPhone {
            ToolbarItem(placement: .primaryAction) { filterMenu }
        } else {
            if model.me?.isAdmin == true {
                ToolbarItem(placement: .secondaryAction) { icalMenu }
            }
            if view == .week {
                ToolbarItem(placement: .secondaryAction) { weekStyleMenu }
            }
        }
    }

    var stepNoun: String {
        switch view {
        case .week: return "week"
        case .day: return "day"
        default: return "month"
        }
    }

    /// `.calbar`: the ‹ › capsule, then the kind chips (scrolling).
    var calBar: some View {
        HStack(spacing: 8) {
            if view != .forecast {
                CalNavButtons(noun: stepNoun, onPrev: { step(-1) }, onToday: nil, onNext: { step(1) })
            }
            kindChips
        }
    }

    var kindChips: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(CalendarMediaFilter.allCases, id: \.self) { value in
                        CalKindChip(filter: value, on: filter == value) {
                            withAnimation(motionOff ? nil : .snappy(duration: 0.2)) { filter = value }
                        }
                    }
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 1)
            }
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.selection, trigger: filter)
    }

    var icalMenu: some View {
        Menu {
            Button("Copy feed URL", systemImage: "doc.on.doc") { Task { await feedURL(subscribe: false) } }
            Button("Subscribe in Calendar", systemImage: "calendar.badge.plus") { Task { await feedURL(subscribe: true) } }
        } label: {
            Label("iCal feed", systemImage: "dot.radiowaves.up.forward")
        }
        .disabled(copyingFeed)
    }

    var weekStyleMenu: some View {
        Menu {
            Picker("Week card style", selection: weekCardsBinding) {
                Text("Phone cards").tag("phone")
                ForEach(WeekCardStyle.allCases, id: \.self) { style in
                    Text(style.label).tag(style.rawValue)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label("Week card style", systemImage: "rectangle.stack")
        }
    }

    // MARK: Legends (`.legend`)

    var legends: some View {
        VStack(alignment: .leading, spacing: 8) {
            statusLegend
            releaseLegend
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(Theme.dim)
        .lineLimit(1)
        .padding(.top, 2)
    }

    private var statusLegend: some View {
        HStack(spacing: 12) {
            ForEach(CalendarStatusKey.allCases, id: \.self) { key in
                HStack(spacing: 5) {
                    Circle().fill(key.color).frame(width: 7, height: 7)
                    Text(key.label)
                }
            }
        }
    }

    private var releaseLegend: some View {
        HStack(spacing: 12) {
            ForEach(MovieReleaseType.allCases, id: \.self) { type in
                HStack(spacing: 5) {
                    Image(systemName: type.symbol)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(type.color)
                        .frame(width: 14, height: 14)
                    Text(type.label)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Movie release types: Theatrical, Digital, Physical")
    }
}
