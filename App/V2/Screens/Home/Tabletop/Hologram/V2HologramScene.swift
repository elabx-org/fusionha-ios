import SwiftUI
import FusionhaKit

/// The hologram scene across Home's whole container (tabletop plan, slice
/// 2; the approved mock's B2): the top half's layer above the hinge and the
/// bottom half's below it, each clipped to its half (`V2HologramHalf`).
/// `position` is the focused card's index and `hinge` the hinge angle; both
/// animate, so a turn of the ring and a change of angle re-draw the picture
/// frame by frame. The scene only shows: it takes no touches (the page
/// reads them, `V2HologramPage`).
struct V2HologramScene: View, Animatable {
    let space: V2TabletopSpace
    let cards: [V2ComingUpCard]
    let art: [Int: V2HologramArt]
    let look: V2HologramLook
    var position: Double
    var hinge: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(position, hinge) }
        set {
            position = newValue.first
            hinge = newValue.second
        }
    }

    var body: some View {
        let rig = V2HologramRig(space: space, hingeDegrees: hinge)
        let placed = V2HologramPlaced.all(cards, position: position, art: art)
        VStack(spacing: 0) {
            V2HologramHalf(half: .top, rig: rig, placed: placed, look: look)
            V2HologramHalf(half: .bottom, rig: rig, placed: placed, look: look)
        }
        .frame(width: space.size.width, height: space.size.height, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Feeds the scene: loads the cards' posters (the focused one first) and
/// the focused title's light, the lead colour of its art
/// (`ArtPaletteExtractor`, the colours Home's ground is built from).
struct V2HologramStage: View {
    let space: V2TabletopSpace
    let cards: [V2ComingUpCard]
    let current: V2ComingUpCard
    let hinge: Double
    @Environment(\.displayScale) private var displayScale
    @Environment(\.pagePalette) private var page
    @State private var art: [Int: V2HologramArt] = [:]
    @State private var loaded: (key: String, colors: [HSLColor])?

    private var index: Int { cards.firstIndex { $0.id == current.id } ?? 0 }
    private var isLight: Bool { page?.isLight ?? Theme.isLight }

    private var sample: URL? {
        ArtPaletteExtractor.sampleURL(current.item.posterUrl ?? current.item.backdropUrl)
    }

    /// The focused art's colours: the cached ones at once, else once loaded.
    private var dominant: [HSLColor]? {
        guard let sample else { return nil }
        if let hit = ArtPaletteExtractor.shared.cached(sample) { return hit }
        return loaded?.key == sample.absoluteString ? loaded?.colors : nil
    }

    var body: some View {
        let look = V2HologramLook(tint: V2HologramLook.tint(dominant, mono: page?.isMono ?? Theme.isMono),
                                  isLight: isLight)
        V2HologramScene(space: space, cards: cards, art: art, look: look, position: Double(index), hinge: hinge)
            .task(id: cards.map(\.id)) { await loadArt() }
            .task(id: sample) { await loadColors() }
    }

    private func loadArt() async {
        let ids = Set(cards.map(\.id))
        art = art.filter { ids.contains($0.key) }
        // Nearest the focus first, so the slab is there before the markers.
        let order = cards.enumerated().sorted { abs($0.offset - index) < abs($1.offset - index) }.map(\.element)
        for card in order where art[card.id] == nil {
            guard let loaded = await V2HologramArt.load(card.item, scale: displayScale), !Task.isCancelled else { continue }
            art[card.id] = loaded
        }
    }

    private func loadColors() async {
        guard let sample, ArtPaletteExtractor.shared.cached(sample) == nil else { return }
        guard let colors = await ArtPaletteExtractor.shared.colors(for: sample), !Task.isCancelled else { return }
        loaded = (sample.absoluteString, colors)
    }
}
