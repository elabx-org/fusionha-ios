import SwiftUI
import FusionhaKit

/// The hero's full-bleed art (MobileHero `.bg` + `.wash`): the poster eases in
/// from a slight zoom (not under Reduce Motion) and fades into the ground.
/// Shared by the loaded hero and the loading shell.
struct DetailHeroArt: View {
    @Environment(\.detailReduceMotion) private var reduce
    let url: URL?
    @State private var artShown = false

    var body: some View {
        Color.clear
            .containerRelativeFrame(.vertical) { length, _ in Self.height(for: length) }
            .frame(maxWidth: .infinity)
            .background {
                art
                wash
            }
            .clipped()
    }

    /// Half the container, at least 360 and at most 520, but the 360 floor
    /// gives way to 60% of a short container (the Duo's outer display held
    /// sideways, 466pt tall) so the heading and actions stay in view (D3).
    static func height(for length: CGFloat) -> CGFloat {
        min(max(length * 0.5, min(360, length * 0.6)), 520)
    }

    @ViewBuilder
    private var art: some View {
        if url != nil {
            PosterImage(url: url)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .mask(LinearGradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.45),
                    .init(color: .clear, location: 0.95),
                ], startPoint: .top, endPoint: .bottom))
                // Ken-Burns settle: the art eases in from a slight zoom.
                .scaleEffect(artShown || reduce ? 1 : 1.06)
                .opacity(artShown || reduce ? 1 : 0)
                .onAppear {
                    guard !reduce else { return }
                    withAnimation(DetailMotion.reveal(0.9)) { artShown = true }
                }
        } else {
            RadialGradient(colors: [Theme.panel2, Theme.bg], center: .top, startRadius: 0, endRadius: 520)
        }
    }

    /// The `.hero-fade`: the art sinks into the ground under the heading.
    private var wash: some View {
        LinearGradient(stops: [
            .init(color: Theme.bg.opacity(0.18), location: 0),
            .init(color: .clear, location: 0.2),
            .init(color: Theme.bg.opacity(0.75), location: 0.62),
            .init(color: Theme.bg.opacity(0.92), location: 1),
        ], startPoint: .top, endPoint: .bottom)
        .allowsHitTesting(false)
    }

}
