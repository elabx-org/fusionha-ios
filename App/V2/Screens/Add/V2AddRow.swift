import SwiftUI
import FusionhaKit

/// One Add result in list view (owner-approved Add results mock, 2026-11-08):
/// a row on the v2 list surface, like All titles' list. Poster thumb, the
/// title, "year · kind", two lines of overview, then Add (+) or, for a title
/// you have, its HD and 4K tickets over Open. TMDB and TVDB rows are the same.
struct V2AddRow: View {
    let card: AddResultCard
    let first: Bool
    let last: Bool
    let pick: () -> Void
    let preview: (() -> Void)?
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }
    private var owned: MediaItem? {
        guard let id = card.libraryItemId else { return nil }
        return model.library.first { $0.id == id }
    }

    var body: some View {
        HStack(spacing: 11) {
            PosterImage(url: TMDBImage.resized(card.posterUrl, to: "w154"), size: CGSize(width: 40, height: 60))
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text(TitleYear.display(card.title, nil).title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                Text(card.subline)
                    .font(.system(size: 11.5))
                    .foregroundStyle(muted)
                    .lineLimit(1)
                if let overview = card.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.system(size: 12))
                        .foregroundStyle(muted.opacity(0.8))
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture(perform: pick)
        .background { V2ListRowSurface(first: first, last: last) }
        .contextMenu {
            if let preview { Button("Preview", systemImage: "eye", action: preview) }
            Button(card.inLibrary ? "Open" : "Add", systemImage: card.inLibrary ? "chevron.right" : "plus",
                   action: pick)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .modifier(V2AddPreviewAction(preview: preview))
    }

    @ViewBuilder
    private var trailing: some View {
        if card.inLibrary {
            VStack(alignment: .trailing, spacing: 6) {
                if let owned {
                    let badges = V2EditionBadges(owned) { model.queueSlots.slot(for: $0.id).progress }
                    EditionTicketPair(hd: badges.hd, uhd: badges.uhd)
                }
                HStack(spacing: 2) {
                    Text("Open")
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(muted)
            }
            .accessibilityElement(children: .combine)
        } else {
            V2AddPlus(title: card.title, action: pick).padding(-7)
        }
    }
}
