import SwiftUI
import FusionhaKit

/// The Library home's hero carousel (mock browse.js `home`): big art cards
/// that scroll sideways and snap. On a phone the card is centred with its
/// neighbours peeking (art only, their footer hidden); on the folded Duo the
/// cards lead from the gutter and run on under the column; across the flat
/// open Duo five smaller cards sit in a row straight over the fold.
struct V2LibraryHeroCarousel: View {
    let items: [MediaItem]
    /// The page's own width.
    let width: CGFloat
    /// The page's side gutter (the carousel sits inside it).
    let gutter: CGFloat
    @Environment(\.motionEnabled) private var motion
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var centred: Int?

    private static let spacing: CGFloat = 14

    private var wide: Bool { width >= 700 }
    private var foldedDuo: Bool { !wide && OuterDisplay.isFoldedDuo(sizeClass: sizeClass) }
    /// The phone centres a card; elsewhere the row leads from the gutter.
    private var centres: Bool { !wide && !foldedDuo }

    /// The mock's three sizes: flat open 196×258, folded 290×262, phone 240×280.
    private var cardSize: CGSize {
        if wide { return CGSize(width: 196, height: 258) }
        if foldedDuo { return CGSize(width: min(290, width - 2 * gutter), height: 262) }
        return CGSize(width: min(240, width - 2 * gutter), height: 280)
    }

    /// Leading inset that centres a card on the page (the scroll view itself
    /// starts at the gutter).
    private var centreMargin: CGFloat {
        centres ? max(0, (width - cardSize.width) / 2 - gutter) : 0
    }

    var body: some View {
        let size = cardSize
        let current = centred ?? items.first?.id
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: Self.spacing) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    V2LibraryHeroCard(item: item, width: size.width, height: size.height,
                                      showsFooter: wide || item.id == current)
                        .landing(i, motion: motion)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, centreMargin, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $centred)
        // Neighbours peek past the gutter, and the folded Duo's row runs on
        // under the column to the screen edge.
        .scrollClipDisabled()
        .frame(height: size.height + 24, alignment: .top)
        .accessibilityLabel("Featured")
    }
}
