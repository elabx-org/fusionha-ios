import SwiftUI

/// The print-in's scan bar (the approved mock's `.scan`): a bright line
/// with the title's light either side, drawn across the slab at the height
/// it is printed to. The glow is a gradient, not a blur.
struct V2HologramScan: View {
    let look: V2HologramLook

    /// The bar's plate before projection: the slab's width, the line in the
    /// middle of its height.
    static let box = CGSize(width: V2HologramArt.box.width, height: 44)
    /// The plate's half height in the scene's points.
    static let reach = 22.0

    var body: some View {
        ZStack {
            LinearGradient(stops: [.init(color: look.tint.opacity(0), location: 0),
                                   .init(color: look.tint.opacity(look.isLight ? 0.5 : 0.85), location: 0.5),
                                   .init(color: look.tint.opacity(0), location: 1)],
                           startPoint: .top, endPoint: .bottom)
            Capsule()
                .fill(look.isLight ? look.ring : Color.white)
                .frame(height: 8)
        }
        .frame(width: Self.box.width, height: Self.box.height)
    }
}
