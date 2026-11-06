import SwiftUI
import FusionhaKit

/// How a product dresses the shared Add title flow (`AddTitleSheet`): nil is
/// v1's look. v2 (`V2AddLook`) puts Find and the setup on its page grounds
/// (the art's palette on the setup), shows results as its Library cards,
/// draws the versions in one ink (CLAUDE.md: the letters name the version,
/// not a hue), spreads Find | setup across the flat open Duo too, and opens
/// the new title once it is added.
struct AddLookOverride {
    /// Find's ground (kinds, source, search, the grid), behind `content`.
    let findGround: (AnyView) -> AnyView
    /// The setup's ground from the pick's art (backdrop, poster), behind
    /// `content`; it also sets `\.pagePalette`, whose inks the setup uses.
    let setupGround: (AnyView, String?, String?) -> AnyView
    /// A section card (details, versions, when to grab, monitor) at `radius`.
    let card: (AnyView, CGFloat) -> AnyView
    /// One result in Find's grid: the result, pick, preview.
    let tile: (MediaSearchResult, @escaping () -> Void, @escaping () -> Void) -> AnyView
    /// The grid's column width range (the Library card's).
    let tileWidth: ClosedRange<CGFloat>
    /// Find | setup across a page this wide with no fold through it (the flat
    /// open Duo, an iPad): Find takes `lead` of it.
    let flatSpread: (_ width: Double, _ height: Double) -> FoldColumns.Panes?
}

private struct AddLookKey: EnvironmentKey {
    static let defaultValue: AddLookOverride? = nil
}

extension EnvironmentValues {
    var addLook: AddLookOverride? {
        get { self[AddLookKey.self] }
        set { self[AddLookKey.self] = newValue }
    }
}

extension View {
    /// v2's ground for Find (`AddLookOverride.findGround`), else v1's panel.
    @ViewBuilder
    func addFindGround(_ look: AddLookOverride?) -> some View {
        if let look { look.findGround(AnyView(self)) } else { background(Theme.panel) }
    }

    /// A setup section's card: v2's (`AddLookOverride.card`), else v1's.
    @ViewBuilder
    func addCard(_ look: AddLookOverride?, radius: CGFloat) -> some View {
        if let look {
            look.card(AnyView(self), radius)
        } else {
            background(Theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }
}

/// The inks a setup in one look draws with: v1's tier colours, or the page's
/// ink (v2: one ink, the letters name the version).
struct AddInks {
    let look: AddLookOverride?
    let page: PagePalette?

    var ink: Color { page?.ink ?? Theme.txt }
    var muted: Color { page?.inkMuted ?? Theme.mut }
    func tier(_ tier: QualityTier) -> Color { look == nil ? tier.color : ink }
    /// A switch's on colour: the tier's (v1), the palette's primary (v2).
    func toggle(_ tier: QualityTier) -> Color { look == nil ? tier.color : Theme.primary }
}

/// The setup's ground: v2's art ground (`AddLookOverride.setupGround`), else
/// v1's page colour (the ambient art is drawn by the setup itself).
struct AddSetupGround: ViewModifier {
    let look: AddLookOverride?
    let backdrop: String?
    let poster: String?

    func body(content: Content) -> some View {
        if let look {
            look.setupGround(AnyView(content), backdrop, poster)
        } else {
            content.background(Theme.bg)
        }
    }
}
