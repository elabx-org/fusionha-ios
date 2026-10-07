import SwiftUI
import UIKit
import WidgetKit

/// The small Recently added hero: the whole 2:3 poster, sharp and uncropped,
/// centred on a blurred, dimmed wash of itself that fills the wide slot edge
/// to edge. Filling the slot with the poster itself cut a portrait poster to
/// a strip of its middle. No text on the art; the caption sits underneath.
struct WidgetPosterHero: View {
    let data: Data?

    var body: some View {
        if let data, let image = UIImage(data: data) {
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .widgetAccentedRenderingMode(.accentedDesaturated)
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 16, opaque: true)
                    .overlay(Color.black.opacity(0.35))
                Image(uiImage: image)
                    .resizable()
                    .widgetAccentedRenderingMode(.accentedDesaturated)
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: WidgetStyle.posterRadius, style: .continuous))
                    .shadow(color: .black.opacity(0.45), radius: 6, y: 3)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
            }
        } else {
            WidgetPosterPlaceholder()
        }
    }
}
