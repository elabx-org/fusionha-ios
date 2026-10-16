import SwiftUI
import FusionhaKit

// MARK: Calendar rails (`routes/calendar/rails.tsx`)
//
// The library's coverage rail, so the calendar follows Settings › Library's
// rail style (Current / Fill only / Trailing dot) and HD + 4K consolidation.
// Not-yet-aired reads "Soon".

struct CalRails: View {
    let units: [CalendarRailUnit]
    var rowGap: CGFloat = 8
    var columnGap: CGFloat = 16

    var body: some View {
        CalFlow(spacing: columnGap, lineSpacing: rowGap) {
            ForEach(Array(units.enumerated()), id: \.offset) { _, unit in
                RailRowView(rail: unit.rail, tier: unit.tier, combo: unit.combo, inline: true, upcomingText: "Soon")
            }
        }
    }
}

/// The Agenda's rail column (`.evRails`): one rail per line, bars aligned.
struct CalRailStack: View {
    let units: [CalendarRailUnit]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(units.enumerated()), id: \.offset) { _, unit in
                RailRowView(rail: unit.rail, tier: unit.tier, combo: unit.combo, inline: true, upcomingText: "Soon")
            }
        }
    }
}
