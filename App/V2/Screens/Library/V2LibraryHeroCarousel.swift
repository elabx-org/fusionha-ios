import SwiftUI
import FusionhaKit

/// The Library home's hero carousel (mock browse.js `home`): big art cards
/// that scroll sideways and snap. On a phone the card is centred with its
/// neighbours peeking (art only, their footer hidden); on the folded Duo the
/// cards lead from the gutter and run on under the column; across the flat
/// open Duo about 4.4 smaller cards sit in a row straight over the fold, the
/// next one peeking under the system column so the row reads as scrolling.
struct V2LibraryHeroCarousel: View {
    let items: [MediaItem]
    /// The page's own width.
    let width: CGFloat
    /// The page's side gutter (the carousel sits inside it).
    let gutter: CGFloat
    /// Each card's reason line by title id ("Digital · Fri", the "Coming up" row).
    var notes: [Int: String] = [:]
    @Environment(\.motionEnabled) private var motion
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var centred: Int?

    private static let spacing: CGFloat = 14

    private var wide: Bool { width >= 700 }
    private var foldedDuo: Bool { !wide && OuterDisplay.isFoldedDuo(sizeClass: sizeClass) }
    /// The phone centres a card; elsewhere the row leads from the gutter.
    private var centres: Bool { !wide && !foldedDuo }

    /// Past the page's trailing edge the row's scroll view reaches on under
    /// the column (gutter + the column's inset, with room to spare). Its
    /// cards are laid out there, not just drawn unclipped: a lazy row only
    /// builds the cards inside its own bounds, so without it the row stopped
    /// at the last whole card. The phone's centred row keeps its own bounds.
    private var bleed: CGFloat { centres ? 0 : gutter + 120 }

    /// Flat open: about 4.4 cards from the gutter to the page's edge, in the
    /// mock's 196×258 proportion. Folded 290×262, phone 240×280.
    private var cardSize: CGSize {
        if wide {
            let span = width - gutter
            let w = min(220, max(160, (span - 4 * Self.spacing) / 4.4)).rounded()
            return CGSize(width: w, height: (w * 258 / 196).rounded())
        }
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
                                      showsFooter: wide || item.id == current, note: notes[item.id])
                        .landing(i, motion: motion)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.leading, centreMargin, for: .scrollContent)
        .contentMargins(.trailing, centreMargin + bleed, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $centred)
        // Neighbours peek past the gutter, and the folded Duo's row runs on
        // under the column to the screen edge.
        .scrollClipDisabled()
        .frame(height: size.height + 24, alignment: .top)
        // Pulled out under the column, the scroll view would otherwise add the
        // column's inset to its trailing content margin and the last card
        // would stop short of the page edge.
        .ignoresSafeArea(.container, edges: .trailing)
        .padding(.trailing, -bleed)
        .accessibilityLabel(notes.isEmpty ? "Featured" : "Coming up")
    }
}
