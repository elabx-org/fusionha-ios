import SwiftUI
import UIKit
import WidgetKit
import FusionhaKit

/// A clean poster (no text on art) or the web's dark gradient placeholder.
struct WidgetPoster: View {
    let data: Data?
    var radius: CGFloat = 4

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .widgetAccentedRenderingMode(.accentedDesaturated)
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: [Theme.panel2, Theme.card], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay(Image(systemName: "film").font(.caption2).foregroundStyle(.tertiary))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
