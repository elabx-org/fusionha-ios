import SwiftUI
import FusionhaKit

/// The title's art as one header band across the whole flat open display
/// (mock browse-title.js `tabWide`): the textless art, the hero's shade, and
/// on its foot the title in white with the meta line. As tall as the split
/// view's hero (`V2TitleHero.height`; owner 2026-11-18, replacing the mock's
/// 132 pt `heroBlock`, which looked tiny across the display), so the art
/// keeps its size when the title goes full width.
/// The title filling the display and its pushed seasons and episodes
/// (`V2TitleWideChild`) share it. Content, not glass.
struct V2TitleBand: View {
    let detail: ItemDetail
    /// The bar's reach: the heading always clears it.
    let barInset: CGFloat
    @Environment(\.pagePalette) private var page
    @Environment(\.motionEnabled) private var motion
    @State private var shown = false

    private var light: Bool { page?.isLight ?? Theme.isLight }
    private var art: URL? { ItemDetailArt.hero(backdrop: detail.backdropUrl, poster: detail.posterUrl) }

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .containerRelativeFrame(.vertical) { length, _ in
                max(V2TitleHero.height(for: length, series: detail.isSeries), barInset + 96)
            }
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
                // Under the Duo's column to the display's edge, as the split
                // view's hero does (owner, 2026-11-18).
                .ignoresSafeArea(.container, edges: .horizontal)
                .accessibilityHidden(true)
            }
            // The art and its shade are sized by the art's aspect fill (about
            // 950 x 535 pt for a backdrop across the display), not by the
            // band, so the band clips them to its top and bottom (unclipped
            // they ran ~300 pt down behind the tabs and columns, owner's
            // screenshot); its sides stay open for the bleed (`HeroBleedClip`).
            .clipShape(HeroBleedClip())
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
