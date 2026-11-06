import SwiftUI
import FusionhaKit

/// v2's dress for the browse pages (`BrowseLookOverride`, set in
/// `V2RootView`; slice S11, mock discover.js, discover-cal.js and the
/// unified search): Discover on the hero's art ground, Calendar and Search
/// on the palette's tint ground, the Add-collection page on the
/// collection's art, lanes and day lists on W1 cards, and every owned
/// title's versions as the Library's one-ink HD and 4K tickets.
enum V2BrowseLook {
    static let override = BrowseLookOverride(
        ground: { content, backdrop, poster in
            // The pages draw their own art (hero, header): the ground takes its colours.
            AnyView(content.v2PageGround(art: PageArtSource.url(backdrop: backdrop, poster: poster),
                                         recipe: .page, showsArt: false))
        },
        card: { content, radius in AnyView(content.v2CardStyle(padding: 0, radius: radius)) },
        tickets: { item in AnyView(V2ItemTickets(item: item)) },
        caption: { item in AnyView(V2PosterCaption(item: item)) })
}

/// An owned title's HD and 4K as one T5 ticket, with its live downloads
/// (`QueueSlots`, so a poll moving another title leaves it alone).
struct V2ItemTickets: View {
    let item: MediaItem
    @Environment(AppModel.self) private var model

    var body: some View {
        let slots = model.queueSlots
        let badges = V2EditionBadges(item) { slots.slot(for: $0.id).progress }
        EditionTicketPair(hd: badges.hd, uhd: badges.uhd)
    }
}
