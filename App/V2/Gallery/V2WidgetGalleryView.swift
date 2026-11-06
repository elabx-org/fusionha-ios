import SwiftUI
import WidgetKit
import FusionhaKit

/// CI screenshots only (`FUSIONHA_SCREENSHOT_V2WIDGETS`): v2's widgets at
/// their iPhone sizes, fed by the extension's loaders against the mock
/// server, and its Lock Screen Live Activity. `home`: Up next large (Airing
/// tonight) over Needs you and Downloads small. `medium`: This week and
/// Needs you medium, and the smalls again. `live`: the Live Activity's
/// downloading states. Add `FUSIONHA_SCREENSHOT_PALETTE=daylight` for light.
struct V2WidgetGalleryView: View {
    enum Variant: String { case home, medium, live }

    static var screenshotVariant: Variant? {
        #if DEBUG
        ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_V2WIDGETS"].flatMap(Variant.init(rawValue:))
        #else
        nil
        #endif
    }

    let variant: Variant
    @State private var data = V2WidgetGalleryData()
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 14) {
            if !loaded {
                ProgressView()
            } else if variant == .live {
                ForEach(Array(data.activities.enumerated()), id: \.offset) { _, state in
                    V2LiveActivityDownloading(state: state)
                        .foregroundStyle(.white)
                        .padding(16)
                        .frame(width: 370)
                        .background(Color.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                }
            } else if variant == .home {
                card(.systemLarge) { UpNextWidgetView(entry: data.upNext[.systemLarge] ?? .placeholder, family: .systemLarge) }
                smalls
            } else {
                card(.systemMedium) { UpNextWidgetView(entry: data.upNext[.systemMedium] ?? .placeholder, family: .systemMedium) }
                card(.systemMedium) { NeedsYouWidgetView(entry: data.needs, family: .systemMedium) }
                smalls
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(wallpaper.ignoresSafeArea())
        .task {
            data = await V2WidgetGalleryData.load()
            loaded = true
        }
    }

    private var smalls: some View {
        HStack(spacing: 24) {
            card(.systemSmall) { NeedsYouWidgetView(entry: data.needs, family: .systemSmall) }
            card(.systemSmall) { V2DownloadsSmall(entry: data.downloads) }
        }
    }

    private var wallpaper: some View {
        LinearGradient(colors: Theme.isLight ? [Color(hex: 0xC7D2FE), Color(hex: 0xFDE68A)]
                                             : [Color(hex: 0x1E1B4B), Color(hex: 0x0F172A), Color(hex: 0x083344)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func card<Content: View>(_ family: WidgetFamily, @ViewBuilder _ content: () -> Content) -> some View {
        content().galleryWidgetCard(Self.size(family))
    }

    private static func size(_ family: WidgetFamily) -> CGSize {
        switch family {
        case .systemSmall: return CGSize(width: 170, height: 170)
        case .systemMedium: return CGSize(width: 364, height: 170)
        default: return CGSize(width: 364, height: 382)
        }
    }
}
