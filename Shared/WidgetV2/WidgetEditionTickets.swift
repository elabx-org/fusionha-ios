import SwiftUI
import WidgetKit
import FusionhaKit

/// v2's widgets show a title's versions as the app does: the monochrome
/// HD / 4K ticket pair (filled = on disk, outline = missing, ring =
/// downloading, orange "!" = held), never v1's coloured chips. In tinted and
/// clear Home Screens the tickets take the accent like every other figure.
struct WidgetEditionTickets: View {
    let editions: [(tier: QualityTier, status: EditionStatus?)]
    var ink: BadgeInk? = nil

    var body: some View {
        EditionTicketPair(hd: state(.hd), uhd: state(.uhd), showsCount: false)
            .badgeInk(ink ?? .page)
            .widgetAccentable()
            .fixedSize()
    }

    private func state(_ tier: QualityTier) -> EditionBadgeState? {
        guard let edition = editions.first(where: { $0.tier == tier }) else { return nil }
        return EditionBadgeState(status: edition.status ?? .missing)
    }
}
