import SwiftUI
import FusionhaKit

/// Needs you on the open Duo (mock "Coming up as the hero", 2026-11-07): one
/// line in the header row instead of the module, so Coming up can lead the
/// page. The first title's poster, "Needs you · Title" (the caption in
/// orange), what is wrong, and a chevron. One title opens it; several open
/// All titles on Needs attention, and the line says how many more.
struct V2NeedsYouLine: View {
    let items: [MediaItem]
    let held: Set<Int>
    let showAll: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page

    var body: some View {
        if let first = items.first {
            Button { tap(first) } label: { label(first) }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint(items.count > 1 ? "Shows all \(items.count)" : "Opens the title")
        }
    }

    private func label(_ item: MediaItem) -> some View {
        HStack(spacing: 10) {
            PosterImage(url: TMDBImage.resized(item.posterUrl, to: "w185"), size: CGSize(width: 24, height: 36))
                .frame(width: 24, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text("\(Text("Needs you").foregroundStyle(Theme.stuck)) · \(item.title)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(page?.ink ?? Theme.txt)
                Text(note(item))
                    .font(.system(size: 12))
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
            }
            .lineLimit(1)
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(page?.inkMuted ?? Theme.mut)
        }
        .padding(.vertical, 7)
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .v2CardStyle(padding: 0, radius: 16)
        .frame(maxWidth: 390)
    }

    private func note(_ item: MediaItem) -> String {
        let reason = V2NeedsAttentionRow.reason(item, held: held)
        return items.count > 1 ? "\(reason) · \(items.count - 1) more" : reason
    }

    private func tap(_ item: MediaItem) {
        if items.count > 1 { showAll() } else { model.open(item.id) }
    }
}
