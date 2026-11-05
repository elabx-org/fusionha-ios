import SwiftUI
import FusionhaKit

/// The title's art as one header band across the whole flat open display
/// (mock browse-title.js `tabWide`, `heroBlock(132)`): the textless art,
/// the hero's shade, and on its foot the title in white with the meta line.
/// The title filling the display and its pushed seasons and episodes
/// (`V2TitleWideChild`) share it. Content, not glass.
struct V2TitleBand: View {
    let detail: ItemDetail
    let height: CGFloat
    @Environment(\.pagePalette) private var page
    @Environment(\.motionEnabled) private var motion
    @State private var shown = false

    private var light: Bool { page?.isLight ?? Theme.isLight }
    private var art: URL? { ItemDetailArt.hero(backdrop: detail.backdropUrl, poster: detail.posterUrl) }

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background {
                ZStack {
                    PosterImage(url: art)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .opacity(shown || !motion ? 1 : 0)
                    V2HeroShade(light: light, tint: page?.tint)
                    if !light {
                        let tint = page?.tint ?? Theme.bg
                        LinearGradient(colors: [tint.opacity(0), tint.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                            .frame(height: 22)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                }
                .clipped()
                .accessibilityHidden(true)
            }
            .overlay(alignment: .bottomLeading) {
                V2TitleHeading(detail: detail, size: 30, showsTagline: false)
                    .padding(.horizontal, V2TitleWide.gutter)
                    .padding(.bottom, 14)
            }
            .onAppear {
                guard motion, !shown else { return }
                withAnimation(.easeOut(duration: 0.5)) { shown = true }
            }
    }
}
