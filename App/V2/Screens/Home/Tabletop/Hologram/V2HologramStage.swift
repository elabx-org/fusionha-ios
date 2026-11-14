import SwiftUI
import FusionhaKit

/// Feeds the scene: loads the cards' posters (the focused one first) and
/// the focused title's light, the lead colour of its art
/// (`ArtPaletteExtractor`, the colours Home's ground is built from). It is
/// there for as long as Home is on a table, also while the flat carousel
/// shows (`lift` 0, nothing drawn), so the posters are ready the moment the
/// lift starts. It plays the print-in once, when the tabletop appears with
/// the hologram already on (`printsIn`), and runs the idle loop only while
/// the scene is on screen and the app is active.
struct V2HologramStage: View {
    let space: V2TabletopSpace
    let cards: [V2ComingUpCard]
    let current: V2ComingUpCard
    let hinge: Double
    /// The lift's progress: 0 draws nothing, 1 is the hologram.
    var lift: Double = 1
    /// The flat carousel the posters lift from.
    var flat: TabletopLift.Flat?
    /// The tabletop appeared with the hologram on: the scene prints in.
    var printsIn = false
    @Environment(\.displayScale) private var displayScale
    @Environment(\.pagePalette) private var page
    @Environment(\.motionEnabled) private var motion
    @Environment(\.scenePhase) private var phase
    @State private var art: [Int: V2HologramArt] = [:]
    @State private var loaded: (key: String, colors: [HSLColor])?
    @State private var printed = false
    @State private var onScreen = false

    /// The print-in waits this long for the focused poster, then goes anyway.
    private static let artWait: Duration = .milliseconds(1500)

    private var index: Int { cards.firstIndex { $0.id == current.id } ?? 0 }
    private var isLight: Bool { page?.isLight ?? Theme.isLight }
    private var moves: Bool { motion && !V2TabletopHologram.holdsStill }
    /// Nothing is printed yet: only before the print-in, with the hologram standing.
    private var rise: Double { printsIn && !printed && moves && lift >= 1 ? 0 : 1 }

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
        ZStack(alignment: .topLeading) {
            if lift > 0 {
                V2HologramScene(space: space, cards: cards, art: art, look: look, position: Double(index), hinge: hinge,
                                rise: rise, lift: lift, flat: flat, idles: moves,
                                paused: !onScreen || phase != .active)
                    // The room carries on under the bars (the scene itself is Home's container).
                    .background { look.room.opacity(TabletopLift.Stages(lift).floor).ignoresSafeArea() }
                    .transition(.identity)
            }
        }
        .frame(width: space.size.width, height: space.size.height, alignment: .topLeading)
        .allowsHitTesting(false)
        .onAppear { onScreen = true }
        .onDisappear { onScreen = false }
        .task(id: cards.map(\.id)) { await loadArt() }
        .task(id: sample) { await loadColors() }
        .task { await printIn() }
    }

    /// The print-in, once: when the focused poster is in (or after a short
    /// wait), the scene prints from the ring up.
    private func printIn() async {
        guard printsIn, !printed else { return }
        guard moves else {
            printed = true
            return
        }
        let focus = current.id
        let giveUp = ContinuousClock.now + Self.artWait
        while art[focus] == nil, ContinuousClock.now < giveUp, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(50))
        }
        withAnimation(.timingCurve(0.215, 0.61, 0.355, 1, duration: TabletopLift.printDuration)) { printed = true }
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
