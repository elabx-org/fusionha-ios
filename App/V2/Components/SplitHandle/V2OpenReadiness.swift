import Foundation
import FusionhaKit

/// What a title needs before it slides in (owner, build 781: "it loads the
/// details card first and then diffuses the colour after"): its detail and
/// its art's palette, so the page lands whole, in its own colours. Waits at
/// most `limit`; a title opened before is ready at once (both are cached).
@MainActor
enum V2OpenReadiness {
    static func wait(for store: DetailStore, art: URL?, limit: Duration = .milliseconds(420)) async {
        let clock = ContinuousClock()
        let deadline = clock.now + limit
        // The palette is cached by URL, so the page's ground paints with it on its first frame.
        let palette = Task { if let art, ArtPaletteExtractor.shared.cached(art) == nil { _ = await ArtPaletteExtractor.shared.colors(for: art) } }
        defer { palette.cancel() }
        while clock.now < deadline, !Task.isCancelled {
            let paletteReady = art.map { ArtPaletteExtractor.shared.cached($0) != nil } ?? true
            if store.detail != nil, paletteReady { return }
            try? await Task.sleep(for: .milliseconds(16))
        }
    }

    /// The title's art as its page samples it (`V2TitleView.groundArt`).
    static func art(_ store: DetailStore, seed: MediaItem?) -> URL? {
        PageArtSource.url(backdrop: store.detail?.backdropUrl ?? seed?.backdropUrl,
                          poster: store.detail?.posterUrl ?? seed?.posterUrl)
    }
}
