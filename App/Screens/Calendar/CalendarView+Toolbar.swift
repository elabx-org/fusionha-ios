import SwiftUI
import FusionhaKit

// The Calendar toolbar (the mock's calendar head): display title and counts, the
// glass view switcher, the glass bar (‹ Today ›, kind chips, iCal feed, week card
// style) and the status / release legends. Every control here is glass; nothing
// in it is content.
extension CalendarView {
    var toolbar: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                ShellTitleRow(title)
                Text(subline)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.mut)
            }
            CalViewSwitcher(selection: view, motion: !motionOff) { setView($0) }
            calBar
            legends
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var stepNoun: String {
        switch view {
        case .week: return "week"
        case .day: return "day"
        default: return "month"
        }
    }

    /// `.calbar`: the ‹ Today › capsule, the kind chips (scrolling), then the
    /// round glass buttons.
    var calBar: some View {
        HStack(spacing: 8) {
            if view != .forecast {
                CalNavButtons(noun: stepNoun, onPrev: { step(-1) }, onToday: goToday, onNext: { step(1) })
            }
            kindChips
            if model.me?.isAdmin == true {
                icalMenu
            }
            if view == .week {
                weekStyleMenu
            }
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
            CalGlassIcon(systemName: "dot.radiowaves.up.forward")
        }
        .buttonStyle(.plain)
        .disabled(copyingFeed)
        .opacity(copyingFeed ? 0.5 : 1)
        .accessibilityLabel("Copy iCal feed URL")
    }

    var weekStyleMenu: some View {
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
            CalGlassIcon(systemName: "gearshape")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Week card style")
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
                        .font(.system(size: 10, weight: .medium))
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
