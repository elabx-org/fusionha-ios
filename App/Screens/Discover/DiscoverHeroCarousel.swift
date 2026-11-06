import SwiftUI
import FusionhaKit

/// v2's Discover opens on a hero carousel (plan S11, mock discover.js): this
/// week's trending titles of the kind as wide art cards that snap, the
/// neighbours peeking on a phone and a row of them on a wide page. The card
/// in view hands its art to the page ground (`art`). Same data and cache as
/// the Trending rail; nothing shows until it has titles with art.
struct DiscoverHeroCarousel: View {
    let kind: SearchKind
    let canAdd: Bool
    let canRequest: Bool
    @Binding var art: String?
    @Environment(AppModel.self) private var model
    @Environment(\.paneSize) private var pane
    @Environment(\.motionEnabled) private var motion
    @State private var items: [MediaSearchResult] = []
    @State private var centred: String?

    private static let spacing: CGFloat = 12
    private static let gutter: CGFloat = 16

    private var wide: Bool { pane.width >= 700 }

    private var cardSize: CGSize {
        if wide {
            let w = min(340, max(280, (pane.width - 2 * Self.gutter - 2 * Self.spacing) / 2.6)).rounded()
            return CGSize(width: w, height: (w * 0.6).rounded())
        }
        let w = max(240, pane.width - 2 * Self.gutter - 40).rounded()
        return CGSize(width: w, height: (w * 0.64).rounded())
    }

    var body: some View {
        // A placeholder while empty: `.task` never runs on an empty Group.
        VStack(spacing: 0) {
            if items.isEmpty { Color.clear.frame(height: 0) } else { carousel }
        }
        .task(id: kind) { await load() }
        .onChange(of: centred) { syncArt() }
        .onChange(of: items) { syncArt() }
    }

    private var carousel: some View {
        let size = cardSize
        let margin = wide ? Self.gutter : max(Self.gutter, (pane.width - size.width) / 2)
        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: Self.spacing) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    DiscoverHeroCard(result: item, rank: index + 1, size: size,
                                     canAdd: canAdd, canRequest: canRequest)
                        .discoverReveal(index: index, step: 0.04)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, margin, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $centred)
        .scrollClipDisabled()
        .frame(height: size.height)
        // The page pads 16pt; the row runs to the screen's edges.
        .padding(.horizontal, -Self.gutter)
        .padding(.bottom, 28)
        .accessibilityLabel("Trending this week")
    }

    private func syncArt() {
        let current = items.first { $0.id == centred } ?? items.first
        let next = current?.backdropUrl ?? current?.posterUrl
        guard next != art else { return }
        withAnimation(motion ? .easeInOut(duration: 0.4) : nil) { art = next }
    }

    private func load() async {
        guard let client = model.client else { return }
        let kind = self.kind
        let call: (APIClient) async throws -> [MediaSearchResult] = {
            try await $0.discover(kind: kind, list: .trending, window: "week", monetization: nil)
        }
        if items.isEmpty, let kept = await client.cached(call) { items = Self.pick(kept) }
        if let fresh = try? await call(client) { items = Self.pick(fresh) }
    }

    /// The first eight with art to show (the backdrop, else the poster).
    private static func pick(_ rows: [MediaSearchResult]) -> [MediaSearchResult] {
        Array(rows.filter { $0.backdropUrl != nil || $0.posterUrl != nil }.prefix(8))
    }
}
