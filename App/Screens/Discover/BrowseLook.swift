import SwiftUI
import FusionhaKit

/// How a product dresses the browse pages (Discover, Calendar, Search and the
/// Add-collection page): nil is v1's look. v2 (`V2BrowseLook`, slice S11)
/// puts them on its page grounds, rows and lanes on W1 cards, a hero
/// carousel over Discover's rails, and every owned title's versions as the
/// one-ink HD and 4K tickets (CLAUDE.md: the letters name the version).
struct BrowseLookOverride {
    /// The page's ground behind `content`, from art (backdrop, poster); no
    /// art draws the palette's tint ground. Sets `\.pagePalette` below it.
    let ground: (AnyView, String?, String?) -> AnyView
    /// A W1 card behind `content` (which pads itself) at `radius`.
    let card: (AnyView, CGFloat) -> AnyView
    /// An owned title's HD and 4K tickets, its live downloads included.
    let tickets: (MediaItem) -> AnyView
    /// Everything under an owned title's poster: title, tickets, marks.
    let caption: (MediaItem) -> AnyView
}

private struct BrowseLookKey: EnvironmentKey {
    static let defaultValue: BrowseLookOverride? = nil
}

extension EnvironmentValues {
    var browseLook: BrowseLookOverride? {
        get { self[BrowseLookKey.self] }
        set { self[BrowseLookKey.self] = newValue }
    }
}

extension View {
    /// v2's ground for a browse page (`BrowseLookOverride.ground`); v1 keeps
    /// the page colour its `Screen` already draws.
    @ViewBuilder
    func browseGround(_ look: BrowseLookOverride?, backdrop: String? = nil, poster: String? = nil) -> some View {
        if let look { look.ground(AnyView(self), backdrop, poster) } else { self }
    }

    /// A browse card: v2's W1 card, else v1's solid card with its hairline.
    @ViewBuilder
    func browseCard(_ look: BrowseLookOverride?, radius: CGFloat) -> some View {
        if let look {
            look.card(AnyView(self), radius)
        } else {
            background(Theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.line))
        }
    }
}

/// The inks a browse page draws with: the page palette's on a v2 ground,
/// else v1's tokens.
struct BrowseInks {
    let page: PagePalette?

    var ink: Color { page?.ink ?? Theme.txt }
    var muted: Color { page?.inkMuted ?? Theme.mut }
}

extension AppModel {
    /// The library's own item for a Discover or search result, if owned.
    func ownedItem(for result: MediaSearchResult) -> MediaItem? {
        guard let id = libraryItemId(for: result) else { return nil }
        return library.first { $0.id == id }
    }
}
