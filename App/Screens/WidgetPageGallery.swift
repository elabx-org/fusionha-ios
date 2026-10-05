import SwiftUI
import WidgetKit
import FusionhaKit

/// CI screenshots only: one view of the paged Downloads widget at its medium
/// and large sizes, loaded through `WidgetPageLoader` against the mock server.
/// `FUSIONHA_SCREENSHOT_WIDGET_PAGE=downloading|upnext|recent|library|indexers|wanted|requests`.
struct WidgetPageGalleryView: View {
    static var screenshotPage: WidgetPage? {
        #if DEBUG
        ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_WIDGET_PAGE"].flatMap(WidgetPage.init(rawValue:))
        #else
        nil
        #endif
    }

    let page: WidgetPage
    @State private var entries: [WidgetFamily: DownloadsEntry] = [:]

    var body: some View {
        VStack(spacing: 16) {
            Text(page.title).font(.headline).foregroundStyle(.white.opacity(0.8))
            if let medium = entries[.systemMedium], let large = entries[.systemLarge] {
                card(medium, .systemMedium)
                card(large, .systemLarge)
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

    private func card(_ entry: DownloadsEntry, _ family: WidgetFamily) -> some View {
        let size = family == .systemLarge ? CGSize(width: 364, height: 382) : CGSize(width: 364, height: 170)
        return DownloadsWidgetView(entry: entry, family: family)
            .padding(16)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .background(LinearGradient(colors: [Theme.panel, Theme.bg], startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func load() async {
        guard let server = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_SERVER"].flatMap(URL.init(string:)) else {
            return
        }
        let client = APIClient(baseURL: server, token: "screenshot")
        for family in [WidgetFamily.systemMedium, .systemLarge] {
            let large = family == .systemLarge
            var entry = await WidgetLoader.downloads(client, limit: large ? 4 : 2, idleUpNext: 0, idleRecent: 0)
            entry.pages = WidgetPage.allCases
            entry.page = page
            await WidgetPageLoader.load(page, into: &entry, client, large: large)
            entries[family] = entry
        }
    }
}
