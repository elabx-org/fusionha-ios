import SwiftUI
import FusionhaKit

/// The poster page while its title loads, drawn from what the tapped poster
/// already knew (art, title) in the loaded page's own geometry: the phone's
/// full poster hero, or the open Duo's band with the album cover. The page
/// then fills in where the shell stood instead of swapping today's shell
/// (backdrop, big title on the left) for a different layout. Behind
/// `TitleLook.posterKey`.
struct V2PosterLoadingShell: View {
    @Environment(\.v2TitleBarInset) private var barInset
    let seed: MediaItem?
    let width: CGFloat
    let wide: Bool

    var body: some View {
        Group {
            if wide { wideShell } else { phoneShell }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading title")
    }

    private var phoneShell: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: V2PosterHero.height(width: width))
                .background { V2PosterHeroArt(poster: seed?.posterUrl, backdrop: seed?.backdropUrl) }
                .overlay(alignment: .bottomLeading) {
                    heading(size: 30, centred: false)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
            skeleton(lines: 6)
                .padding(.horizontal, width >= 560 ? 24 : 20)
                .padding(.top, 16)
        }
    }

    private var wideShell: some View {
        let left = V2PosterWidePage.leftWidth(width)
        return VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 16) {
                V2PosterCover(poster: seed?.posterUrl, backdrop: seed?.backdropUrl, width: V2PosterWidePage.posterWidth)
                heading(size: 26, centred: true)
            }
            .frame(width: left)
            .padding(.leading, V2TitleWide.gutter)
            .padding(.top, barInset + 8)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { V2PosterWideHero(backdrop: seed?.backdropUrl, poster: seed?.posterUrl) }
            HStack(alignment: .top, spacing: V2TitleWide.columnGap) {
                skeleton(lines: 4).frame(width: left)
                skeleton(lines: 5)
            }
            .padding(.horizontal, V2TitleWide.gutter)
            .padding(.top, 14)
        }
    }

    /// The title in white as the loaded heading sets it, and a bar where the
    /// meta line lands.
    private func heading(size: CGFloat, centred: Bool) -> some View {
        VStack(alignment: centred ? .center : .leading, spacing: centred ? 6 : 8) {
            if let seed {
                Text(seed.title)
                    .font(.system(size: size, weight: .heavy))
                    .tracking(-size * 0.03)
                    .multilineTextAlignment(centred ? .center : .leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.white)
            } else {
                SkeletonBar(height: size, radius: 8).frame(maxWidth: 220)
            }
            SkeletonBar(height: 15).frame(maxWidth: 200)
        }
        .frame(maxWidth: .infinity, alignment: centred ? .center : .leading)
    }

    private func skeleton(lines: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonBar(height: 12).frame(maxWidth: .infinity)
            SkeletonBar(height: 12).frame(maxWidth: 220)
            ForEach(0..<lines, id: \.self) { _ in SkeletonBar(height: 52, radius: 14) }
        }
        .padding(.bottom, 32)
    }
}
