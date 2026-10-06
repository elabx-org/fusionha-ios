import SwiftUI
import WidgetKit

/// CI screenshots only: `FUSIONHA_SCREENSHOT_WIDGET_ACCENTED=1` lays the gallery
/// widgets out as in accented (tinted) rendering. The real mode can't be forced
/// in the app, so this approximates it: the accented-mode fills
/// (`widgetAccentPreview`), greyscale, and a translucent card.
enum WidgetGalleryAccent {
    static var isOn: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_WIDGET_ACCENTED"] == "1"
        #else
        false
        #endif
    }
}

extension View {
    /// A gallery widget card at `size`, full colour or accented.
    func galleryWidgetCard(_ size: CGSize) -> some View {
        let accented = WidgetGalleryAccent.isOn
        return environment(\.widgetAccentPreview, accented)
            .grayscale(accented ? 1 : 0)
            .padding(16)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .background {
                if accented {
                    Color.white.opacity(0.12)
                } else {
                    LinearGradient(colors: [Theme.panel, Theme.bg], startPoint: .top, endPoint: .bottom)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
