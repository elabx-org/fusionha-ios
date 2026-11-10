import SwiftUI
import FusionhaKit

/// The poster-led page's hero on a phone (mock "Closed", option A): the
/// poster full width at its own 2:3, never taller than 680pt, its foot
/// shaded into the page tint, and on that foot the title and meta line in
/// white. Content, not glass.
struct V2PosterHero: View {
    let detail: ItemDetail
    /// The page's width; the hero's height follows the poster's shape.
    let width: CGFloat
    @Environment(\.pagePalette) private var page
    @Environment(\.motionEnabled) private var motion
    @State private var shown = false

    private var light: Bool { page?.isLight ?? Theme.isLight }
    private var art: URL? { TMDBImage.resized(detail.posterUrl ?? detail.backdropUrl, to: "w780") }
    private var height: CGFloat { min(max(width, 300) * 1.5, 680) }

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background {
                ZStack {
                    PosterImage(url: art)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .scaleEffect(shown || !motion ? 1 : 1.04)
                        .opacity(shown || !motion ? 1 : 0)
                    V2HeroShade(light: light, tint: page?.tint)
                    V2PosterFoot(light: light, tint: page?.tint)
                }
                .clipped()
                .accessibilityHidden(true)
            }
            .overlay(alignment: .bottomLeading) {
                V2TitleHeading(detail: detail, size: 30)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            .duoTitleSwipe(id: detail.id)
            .onAppear {
                guard motion, !shown else { return }
                withAnimation(.easeOut(duration: 0.7)) { shown = true }
            }
    }
}

/// A poster carries its own title and credits low down; this deeper foot
/// keeps them from showing through the white title (the mock's fade:
/// most of the tint by two thirds down). Light palettes keep the hero
/// shade's dark edge, which the white title needs.
struct V2PosterFoot: View {
    let light: Bool
    let tint: Color?

    var body: some View {
        let foot = light ? Color(red: 30 / 255, green: 18 / 255, blue: 12 / 255) : (tint ?? Theme.bg)
        LinearGradient(stops: [
            .init(color: foot.opacity(0), location: 0.42),
            .init(color: foot.opacity(light ? 0.35 : 0.6), location: 0.6),
            .init(color: foot.opacity(light ? 0.55 : 0.88), location: 0.8),
            .init(color: foot.opacity(light ? 0.6 : 0.96), location: 1),
        ], startPoint: .top, endPoint: .bottom)
    }
}
