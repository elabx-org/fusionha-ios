import SwiftUI
import FusionhaKit

/// `V2NetworkMarkLine` for a Library title: finds the title's network mark
/// itself (0.4.238+ sends it on the Library row; older servers need the
/// detail, through the session cache), then leads `content` with it.
/// Pass `active: false` for a card that is not showing its line yet, so a
/// peeking card never fetches.
struct V2ItemMarkLine<Content: View>: View {
    let item: MediaItem
    var active = true
    var spacing: CGFloat = 7
    @ViewBuilder let content: Content
    @Environment(AppModel.self) private var model
    @State private var studio: Studio?

    var body: some View {
        V2NetworkMarkLine(studio: studio, spacing: spacing) { content }
            .task(id: active ? item.id : nil) { await load() }
    }

    private func load() async {
        guard active else { return }
        if item.networkName != nil || item.networkLogoUrl != nil {
            studio = item.networkMark
            return
        }
        guard let client = model.client else { return }
        if let known = V2StudioMarkCache.shared.cached(item.id, server: client.baseURL) {
            studio = known
            return
        }
        let mark = await V2StudioMarkCache.shared.mark(for: item.id, client: client)
        guard !Task.isCancelled else { return }
        studio = mark
    }
}
