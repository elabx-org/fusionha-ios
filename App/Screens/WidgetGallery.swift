import SwiftUI
import WidgetKit
import FusionhaKit

/// CI screenshots only: hosts the home-screen widget views at their iPhone family
/// sizes, fed by the same loader the widget extension uses (against the mock
/// server). `FUSIONHA_SCREENSHOT_WIDGETS=downloads|downloads-active|upnext|recent`.
struct WidgetGalleryView: View {
    enum Variant: String {
        case downloads, downloadsActive = "downloads-active", upnext, recent
    }

    static var screenshotVariant: Variant? {
        #if DEBUG
        ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_WIDGETS"].flatMap(Variant.init(rawValue:))
        #else
        nil
        #endif
    }

    let variant: Variant
    @State private var downloads: [WidgetFamily: DownloadsEntry] = [:]
    @State private var upNext: [WidgetFamily: UpNextEntry] = [:]
    @State private var recent: [WidgetFamily: RecentEntry] = [:]
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 12) {
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
        .task { await load() }
    }

    private static func size(_ family: WidgetFamily) -> CGSize {
        switch family {
        case .systemSmall: return CGSize(width: 170, height: 170)
        case .systemMedium: return CGSize(width: 364, height: 170)
        default: return CGSize(width: 364, height: 382)
        }
    }

    /// One widget at its family size. The alternate small shows a fallback state
    /// (Downloads: Recently added when nothing is up next; others: empty).
    private func card(_ family: WidgetFamily, alternate: Bool) -> some View {
        let size = Self.size(family)
        return content(family, alternate: alternate)
            .padding(16)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .background(LinearGradient(colors: [Theme.panel, Theme.bg], startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private func content(_ family: WidgetFamily, alternate: Bool) -> some View {
        switch variant {
        case .downloads, .downloadsActive:
            if let entry = downloadsEntry(family, alternate: alternate) {
                DownloadsWidgetView(entry: entry, family: family)
            }
        case .upnext:
            if let entry = upNext[family] {
                UpNextWidgetView(entry: alternate ? UpNextEntry(date: .now, rows: [], signedIn: true, failed: false) : entry,
                                 family: family)
            }
        case .recent:
            if let entry = recent[family] {
                RecentWidgetView(entry: alternate ? RecentEntry(date: .now, rows: [], signedIn: true, failed: false) : entry,
                                 family: family)
            }
        }
    }

    private func downloadsEntry(_ family: WidgetFamily, alternate: Bool) -> DownloadsEntry? {
        guard var entry = downloads[family] else { return nil }
        if alternate { entry.upNext = [] }
        return entry
    }

    private func load() async {
        guard let server = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_SERVER"].flatMap(URL.init(string:)) else {
            loaded = true
            return
        }
        let client = APIClient(baseURL: server, token: "screenshot")
        let families: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
        for family in families {
            let large = family == .systemLarge
            switch variant {
            case .downloadsActive:
                downloads[family] = await WidgetLoader.downloads(client, limit: large ? 4 : 2, idleUpNext: 0, idleRecent: 0)
            case .downloads:
                // The mock queue is never empty: build the idle entry directly.
                var entry = DownloadsEntry(date: .now, total: 0, rows: [], signedIn: true, failed: false)
                entry.upNext = (try? await WidgetLoader.upNext(
                    client, limit: family == .systemSmall ? 1 : (large ? 3 : 2), posterSize: "w92")) ?? []
                entry.recent = (try? await WidgetLoader.recent(
                    client, limit: family == .systemSmall ? 1 : 5, posterSize: "w154")) ?? []
                downloads[family] = entry
            case .upnext:
                let rows = (try? await WidgetLoader.upNext(
                    client, limit: family == .systemSmall ? 1 : (family == .systemMedium ? 3 : 6), posterSize: "w92")) ?? []
                upNext[family] = UpNextEntry(date: .now, rows: rows, signedIn: true, failed: false)
            case .recent:
                let rows = (try? await WidgetLoader.recent(
                    client, limit: family == .systemSmall ? 1 : (family == .systemMedium ? 5 : 8),
                    posterSize: family == .systemSmall ? "w92" : "w154")) ?? []
                recent[family] = RecentEntry(date: .now, rows: rows, signedIn: true, failed: false)
            }
        }
        loaded = true
    }
}
