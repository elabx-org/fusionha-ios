import SwiftUI
import FusionhaKit

/// The Library's Needs-attention row (plan S4): on top of the home while any
/// title needs the owner (a held download, files missing or unreadable, a
/// dead link). One W1 module with an orange caption, the first three titles
/// with what is wrong, and "Show all", which filters the grid to them.
struct V2NeedsAttentionRow: View {
    let items: [MediaItem]
    /// Titles with a held download in the queue.
    let held: Set<Int>
    let showAll: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page

    var body: some View {
        WidgetModule(caption: "Needs you · \(items.count)", systemImage: "exclamationmark.triangle.fill",
                     needsYou: true) {
            if items.count > 3 {
                Button("Show all", action: showAll)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accentText)
                    .buttonStyle(.plain)
            }
        } content: {
            ForEach(items.prefix(3)) { item in row(item) }
        }
    }

    private func row(_ item: MediaItem) -> some View {
        Button { model.open(item.id) } label: {
            HStack(spacing: 12) {
                PosterImage(url: TMDBImage.resized(item.posterUrl, to: "w185"), size: CGSize(width: 34, height: 51))
                    .frame(width: 34, height: 51)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(page?.ink ?? Theme.txt)
                        .lineLimit(1)
                    Text(reason(item))
                        .font(.system(size: 12.5))
                        .foregroundStyle(page?.inkMuted ?? Theme.mut)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    /// What is wrong, in the owner's words.
    private func reason(_ item: MediaItem) -> String {
        if held.contains(item.id) { return "A download is held · review it in Activity" }
        let flagged = item.editions.filter { $0.attention == true }
        let dead = flagged.reduce(0) { $0 + ($1.deadLinkCount ?? 0) }
        let unresolved = flagged.reduce(0) { $0 + ($1.unresolvedFileCount ?? 0) }
        if dead > 0 && dead == unresolved { return dead == 1 ? "A dead link" : "\(dead) dead links" }
        if unresolved > 0 {
            return unresolved == 1 ? "A file went missing or unreadable" : "\(unresolved) files missing or unreadable"
        }
        return "Open the title to rescan, replace or manage the files"
    }
}
