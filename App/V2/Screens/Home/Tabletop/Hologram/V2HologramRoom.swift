import SwiftUI
import UIKit
import FusionhaKit

/// The hologram's room (tabletop plan, slice 4; the approved mock's
/// "Backdrop: poster colours"): the focused poster's colours, diffused, on
/// the wall above the hinge and mirrored on the floor below it, under a veil
/// of the room's own colour, so a dark palette gets a dim coloured room and
/// a light one a pale one. It cross-fades as the focus changes.
///
/// Nothing is blurred live. The colours are the page ground's own cached
/// bitmap recipe (`ArtBlurSpec.pageGround`, rendered once per poster off the
/// main thread into 96 x 143 px by `ArtBlurCache`), here for the whole
/// poster (2:3) where Home's ground keeps a 16:9 cut of its middle.
///
/// It is the scene's background and runs on under the bars, so it is one
/// layer with no edge at the bar; it finds the hinge from its own place in
/// the scene (`space`).
struct V2HologramRoom: View {
    /// The hinge line, in the scene's coordinates.
    let hingeY: CGFloat
    /// The bottom half's height: the floor's colours fade out down it.
    let floorHeight: CGFloat
    let look: V2HologramLook
    /// The focused title's art (`ArtPaletteExtractor.sampleURL`).
    let art: URL?
    @Environment(\.motionEnabled) private var motion
    /// The last bitmap shown: it stays until the next one is ready.
    @State private var held: (key: String, image: UIImage)?

    /// The scene's coordinate space (`V2HologramStage` names it).
    static let space = "v2-hologram-scene"

    /// The bitmap's recipe on the active palette (grey on a hue-less one).
    static var spec: ArtBlurSpec {
        let t = Theme.palette
        return .pageGround(tone: ArtTone(isLight: t.isLight, isMono: PagePalette.dropsHue(t)), aspect: 2.0 / 3)
    }

    private var key: String? { art.map { Self.spec.key(for: $0.absoluteString) } }

    private var shown: (key: String, image: UIImage)? {
        if let key, let hit = ArtBlurCache.shared.cached(key) { return (key, hit) }
        return held
    }

    var body: some View {
        let now = shown
        GeometryReader { proxy in
            // How far the room runs on above the scene (under the bar).
            let above = max(0, -proxy.frame(in: .named(Self.space)).minY)
            let wall = min(proxy.size.height, hingeY + above)
            let floor = proxy.size.height - wall
            ZStack(alignment: .top) {
                look.room
                if let now {
                    colours(now.image, width: proxy.size.width, wall: wall, floor: floor)
                        .id(now.key)
                        .transition(.opacity)
                }
                veil(wall: wall, floor: floor)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .animation(motion ? .easeInOut(duration: 0.45) : nil, value: now?.key)
        .task(id: key) { await load() }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The poster's colours on the wall and, mirrored at the hinge, on the
    /// floor. Both are cut from one plate of one size, so they meet there.
    private func colours(_ image: UIImage, width: CGFloat, wall: CGFloat, floor: CGFloat) -> some View {
        let plate = CGSize(width: width, height: max(wall, floor, 1))
        let picture = Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: plate.width, height: plate.height)
            .scaleEffect(Self.spec.overscanX)
            .frame(width: plate.width, height: plate.height)
            .clipped()
        return VStack(spacing: 0) {
            picture
                .frame(width: width, height: wall, alignment: .bottom)
                .clipped()
            picture
                .scaleEffect(x: 1, y: -1)
                .frame(width: width, height: floor, alignment: .top)
                .clipped()
                // The mock's floor: whole to 34% of the half, gone by 84%.
                .mask(alignment: .top) {
                    LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.34),
                                           .init(color: .clear, location: 0.84)], startPoint: .top, endPoint: .bottom)
                        .frame(height: floorHeight)
                }
        }
    }

    /// The room's own colour over the poster's: one run from the top of the
    /// wall to the front of the floor, with no step at the hinge.
    private func veil(wall: CGFloat, floor: CGFloat) -> some View {
        let w = look.wallVeil
        return VStack(spacing: 0) {
            LinearGradient(stops: [.init(color: look.room.opacity(w[0]), location: 0),
                                   .init(color: look.room.opacity(w[1]), location: 0.46),
                                   .init(color: look.room.opacity(w[2]), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: wall)
            LinearGradient(stops: [.init(color: look.room.opacity(w[2]), location: 0),
                                   .init(color: look.room.opacity(look.floorVeil), location: 0.3),
                                   .init(color: look.room.opacity(look.floorVeil), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: floor)
        }
    }

    private func load() async {
        guard let art, let key else { return }
        if let hit = ArtBlurCache.shared.cached(key) {
            held = (key, hit)
            return
        }
        guard let made = await ArtBlurCache.shared.image(for: art, spec: Self.spec), !Task.isCancelled else { return }
        held = (key, made)
    }
}
