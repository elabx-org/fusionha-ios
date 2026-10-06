import SwiftUI
import WidgetKit
import FusionhaKit

/// CI screenshots only: one Smart Stack widget at small (and its other state
/// beside it), medium and large, fed by the extension's own loaders against
/// the mock server. `FUSIONHA_SCREENSHOT_STACK=downloading|upnext|recent|library|indexers|requests`;
/// `FUSIONHA_SCREENSHOT_WIDGET_ACCENTED=1` approximates the tinted Home Screen.
struct WidgetStackGalleryView: View {
    enum Variant: String {
        case downloading, upnext, recent, library, indexers, requests

        var stack: WidgetStack? {
            switch self {
            case .downloading: return .downloading
            case .library: return .library
            case .indexers: return .indexers
            case .requests: return .requests
            case .upnext, .recent: return nil
            }
        }
    }

    static var screenshotVariant: Variant? {
        #if DEBUG
        ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_STACK"].flatMap(Variant.init(rawValue:))
        #else
        nil
        #endif
    }

    static let families: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]

    let variant: Variant
    @State private var data = WidgetStackGalleryData()
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 10) {
            if loaded {
                HStack(spacing: 24) {
                    card(.systemSmall, alternate: false)
                    card(.systemSmall, alternate: true)
                }
                card(.systemMedium, alternate: false)
                card(.systemLarge, alternate: false)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [Color(hex: 0x1E1B4B), Color(hex: 0x0F172A), Color(hex: 0x083344)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea())
        .task {
            data = await WidgetStackGalleryData.load(variant)
            loaded = true
        }
    }

    private func card(_ family: WidgetFamily, alternate: Bool) -> some View {
        // Recently added's small poster runs edge to edge (its margins are off).
        let bleed = variant == .recent && family == .systemSmall && !alternate
        return content(family, alternate: alternate).galleryWidgetCard(Self.size(family), bleed: bleed)
    }

    @ViewBuilder
    private func content(_ family: WidgetFamily, alternate: Bool) -> some View {
        switch variant {
        case .upnext:
            if let entry = data.upNext[family] {
                UpNextWidgetView(entry: alternate ? UpNextEntry(date: .now, rows: [], signedIn: true, failed: false) : entry,
                                 family: family)
            }
        case .recent:
            if let entry = data.recent[family] {
                RecentWidgetView(entry: alternate ? RecentEntry(date: .now, rows: [], signedIn: true, failed: false) : entry,
                                 family: family)
            }
        default:
            if let entry = data.stack[family], let stack = variant.stack {
                WidgetStackView(entry: alternate ? WidgetStackGalleryData.alternate(stack) : entry, family: family)
            }
        }
    }

    private static func size(_ family: WidgetFamily) -> CGSize {
        switch family {
        case .systemSmall: return CGSize(width: 170, height: 170)
        case .systemMedium: return CGSize(width: 364, height: 170)
        default: return CGSize(width: 364, height: 382)
        }
    }
}
