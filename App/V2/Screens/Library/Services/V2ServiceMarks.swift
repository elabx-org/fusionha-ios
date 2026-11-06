import SwiftUI
import UIKit
import FusionhaKit

/// The services' one-ink marks for the Service menu. A menu row draws a
/// ready `UIImage` only (no async loading inside a menu), so the marks are
/// loaded when the chip appears: the logo through `ImagePipeline`, then
/// `V2LogoAlpha`'s mask, as a template image the menu tints with its label
/// colour. A logo with no clean silhouette has no mark; the row shows the
/// `tv` symbol and the name.
@MainActor @Observable
final class V2ServiceMarks {
    private(set) var marks: [String: UIImage] = [:]
    @ObservationIgnored private var tried: Set<String> = []

    func mark(_ name: String) -> UIImage? { marks[name] }

    func load(_ services: [V2LibraryService]) async {
        for service in services where !tried.contains(service.name) {
            tried.insert(service.name)
            guard let url = TMDBImage.resized(service.logoUrl, to: "w185") else { continue }
            let logo: UIImage?
            if let hit = ImagePipeline.shared.cached(url) {
                logo = hit
            } else {
                logo = await ImagePipeline.shared.image(for: url)
            }
            guard !Task.isCancelled else { tried.remove(service.name); return }
            guard let logo, let ink = V2LogoAlpha.mask(for: logo, url: url) else { continue }
            marks[service.name] = Self.menuImage(ink)
        }
    }

    /// The mask fitted into a 15pt-tall template image (wide logos capped at
    /// 60pt), so every row's mark reads at one height.
    private static func menuImage(_ ink: UIImage) -> UIImage {
        let aspect = ink.size.height > 0 ? ink.size.width / ink.size.height : 1
        let height: CGFloat = 15
        let width = min(60, max(1, height * aspect))
        let size = CGSize(width: width, height: min(height, width / max(aspect, 0.01)))
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            ink.draw(in: CGRect(origin: .zero, size: size))
        }
        return image.withRenderingMode(.alwaysTemplate)
    }
}
