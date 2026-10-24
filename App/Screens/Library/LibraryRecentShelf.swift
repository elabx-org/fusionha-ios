import SwiftUI
import FusionhaKit

/// "Recently added" (owner-approved layout A): big 16:9 backdrops, each on a
/// glow of its own art, the title, "Added today" and the version chips under
/// the art. It follows the page filters and hides when they leave nothing.
/// On a phone (and the closed Duo) it scrolls sideways with the next card
/// peeking; across an open Duo's spread it is two cards a page with the fold
/// in the gutter between the pages. "See all" sorts the grid newest first.
struct LibraryRecentShelf: View {
    let items: [MediaItem]
    /// Two cards a page across the spread, no sideways scroll.
    let spans: Bool
    /// The page's own width (sizes the phone card so the next one peeks).
    let width: CGFloat
    let seeAll: () -> Void
    @Environment(\.motionEnabled) private var motion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            title
            if spans { spread } else { strip }
        }
    }

    private var title: some View {
        FoldSpanRow {
            HStack(alignment: .firstTextBaseline) {
                LibrarySectionTitle(text: "Recently added")
                Spacer(minLength: 8)
                if !spans { seeAllButton }
            }
        } trailing: {
            if spans {
                seeAllButton.frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var seeAllButton: some View {
        Button("See all", action: seeAll)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.accentText)
            .buttonStyle(.plain)
    }

    /// Phone: a sideways strip; each card is two thirds of the page, so the
    /// next one shows (and on the closed Duo runs on under the column).
    private var strip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 14) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    LibraryRecentCard(item: item)
                        .frame(width: min(max(width * 0.68, 220), 340))
                        .landing(i, motion: motion)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
    }

    /// Open Duo: two a page, the fold in the gutter between the pages.
    private var spread: some View {
        let first = Array(items.prefix(2)), second = Array(items.dropFirst(2).prefix(2))
        return FoldSpanRow {
            pair(first, offset: 0)
        } trailing: {
            pair(second, offset: 2)
        }
    }

    private func pair(_ cards: [MediaItem], offset: Int) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(0..<2, id: \.self) { i in
                if i < cards.count {
                    LibraryRecentCard(item: cards[i]).landing(offset + i, motion: motion)
                } else {
                    Color.clear.frame(height: 1)
                }
            }
        }
    }
}

/// One shelf card: the backdrop (radius 14, shadow, its own glow), then the
/// title, the added line and the chips.
struct LibraryRecentCard: View {
    @Environment(AppModel.self) private var model
    let item: MediaItem

    private var art: URL? {
        TMDBImage.resized(item.backdropUrl ?? item.posterUrl, to: "w780")
    }

    var body: some View {
        Button { model.open(item.id) } label: {
            VStack(alignment: .leading, spacing: 1) {
                PosterImage(url: art)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .shelfPoster(radius: 14)
                    .artGlow(art, radius: 14, aspect: 16 / 9, referenceWidth: 240)
                    .padding(.bottom, 8)
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                    .lineLimit(1)
                if let line = addedLine {
                    Text(line).font(.system(size: 12.5)).foregroundStyle(Theme.mut).lineLimit(1)
                }
                EditionStatusChips(item: item).padding(.top, 5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var addedLine: String? {
        RecentShelf.addedLine(Format.timestamp(item.addedAt) ?? Format.day(item.addedAt), now: Date()) {
            $0.formatted(.dateTime.day().month(.abbreviated))
        }
    }
}

/// A Library section heading ("Recently added", "All titles"): 19pt bold.
struct LibrarySectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 19, weight: .bold))
            .tracking(-0.2)
            .foregroundStyle(Theme.txt)
            .accessibilityAddTraits(.isHeader)
    }
}

extension View {
    /// Data arriving (Duo motion): rises 10pt and fades in, staggered 40ms a
    /// card, a 0.35s spring with no bounce; a plain crossfade under Reduce Motion.
    func landing(_ index: Int, motion: Bool) -> some View {
        modifier(LandingModifier(index: index, motion: motion))
    }
}

private struct LandingModifier: ViewModifier {
    let index: Int
    let motion: Bool
    @State private var landed = false

    func body(content: Content) -> some View {
        content
            .opacity(landed ? 1 : 0)
            .offset(y: landed || !motion ? 0 : 10)
            .onAppear {
                guard !landed else { return }
                let delay = Double(min(index, 6)) * 0.04
                withAnimation(motion ? .spring(duration: 0.35, bounce: 0).delay(delay) : .easeInOut(duration: 0.2)) {
                    landed = true
                }
            }
    }
}
