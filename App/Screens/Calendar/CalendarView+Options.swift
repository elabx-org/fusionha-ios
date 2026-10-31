import SwiftUI
import FusionhaKit

// "Calendar options" (D2): the iCal feed and the week card style, in their own
// titled bar menu so the Filter menu only filters. Phone: the feed for everyone
// and the week cards in every view (as before, in the filter menu); wider:
// the feed for admins and the card style in Week only.
extension CalendarView {
    var showsFeedOptions: Bool { isPhone || model.me?.isAdmin == true }
    var showsWeekCardOptions: Bool { isPhone || view == .week }
    var showsOptionsMenu: Bool { showsFeedOptions || showsWeekCardOptions }

    var optionsMenu: some View {
        Menu {
            if showsFeedOptions {
                Section("iCal feed") {
                    Button("Copy iCal feed URL", systemImage: "dot.radiowaves.up.forward") {
                        Task { await feedURL(subscribe: false) }
                    }
                    .disabled(copyingFeed)
                    Button("Subscribe in Calendar", systemImage: "calendar.badge.plus") {
                        Task { await feedURL(subscribe: true) }
                    }
                    .disabled(copyingFeed)
                }
            }
            if showsWeekCardOptions {
                weekCardsMenu
            }
        } label: {
            Label("Calendar options", systemImage: "gearshape")
        }
    }
}
