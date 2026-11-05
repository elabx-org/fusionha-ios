import SwiftUI
import FusionhaKit

/// The v2 compact list (mock browse-lib.js `clist`): rows on one W1 surface,
/// each a poster thumb, the title, its HD and 4K ticket, "year · profile",
/// the size and the monitor bookmark. Rows stay lazy, so each draws its own
/// slice of the card (rounded only at the ends). Tap opens the title; in
/// Select mode it toggles; long press shows the poster actions.
struct V2LibraryListRow: View {
    let item: MediaItem
    let last: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page

    private var monitored: Bool { item.monitored ?? true }
    private var selected: Bool { model.cardFlags.slot(for: item.id).selected }

    var body: some View {
        Button(action: tapped) {
            HStack(spacing: 11) {
                if model.selectMode {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(selected ? Theme.primary : (page?.inkMuted ?? Theme.mut))
                        .accessibilityHidden(true)
                }
                PosterImage(url: TMDBImage.resized(item.posterUrl, to: "w154"), size: CGSize(width: 36, height: 54))
                    .frame(width: 36, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(monitored ? (page?.ink ?? Theme.txt) : (page?.inkMuted ?? Theme.mut))
                        .lineLimit(1)
                    let badges = V2EditionBadges(item) { model.queueSlots.slot(for: $0.id).progress }
                    EditionTicketPair(hd: badges.hd, uhd: badges.uhd)
                    Text(subline)
                        .font(.system(size: 11.5))
                        .foregroundStyle(page?.inkMuted ?? Theme.mut)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(Format.bytes(item.totalSize))
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 62, alignment: .trailing)
                Image(systemName: monitored ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 15))
                    .foregroundStyle(monitored ? (page?.ink ?? Theme.txt) : (page?.inkMuted ?? Theme.mut).opacity(0.6))
                    .frame(width: 18)
                    .accessibilityLabel(monitored ? "Monitored" : "Not monitored")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background { V2ListRowSurface(last: last) }
        .contextMenu { if !model.selectMode { PosterActions(item: item) } }
        .accessibilityAddTraits(model.selectMode && selected ? .isSelected : [])
    }

    private func tapped() {
        if model.selectMode {
            if selected { model.selection.remove(item.id) } else { model.selection.insert(item.id) }
        } else {
            model.open(item.id)
        }
    }

    private var subline: String {
        var parts: [String] = []
        if let year = item.year { parts.append(String(year)) }
        var seen = Set<Int>()
        let profiles = item.editions.compactMap(\.qualityProfileId).filter { seen.insert($0).inserted }
            .map { model.profileName($0) ?? "#\($0)" }
        parts.append(contentsOf: profiles)
        return parts.joined(separator: " · ")
    }
}

/// One row's slice of the list's W1 surface: the material and wash, the
/// bottom corners on the last row, and a hairline between rows.
struct V2ListRowSurface: View {
    var first = false
    let last: Bool
    @Environment(\.pagePalette) private var page
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let light = page?.isLight ?? Theme.isLight
        let r = ModuleMetrics.radius
        let shape = UnevenRoundedRectangle(topLeadingRadius: first ? r : 0, bottomLeadingRadius: last ? r : 0,
                                           bottomTrailingRadius: last ? r : 0, topTrailingRadius: first ? r : 0,
                                           style: .continuous)
        shape
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, light ? .light : .dark)
            .overlay(shape.fill(ModuleMetrics.wash(light: light)))
            .overlay(alignment: .bottom) {
                // Between rows the rule starts after the thumb (mock `.crow`,
                // left 63); under the head it runs the full width (`.chd`).
                if !last {
                    ModuleMetrics.hairline(light: light)
                        .frame(height: EditionChip.hairline(displayScale))
                        .padding(.leading, first ? 0 : 63)
                }
            }
    }
}

/// The list's head (the first slice of the card): Title and Size sort the
/// rows; a second tap flips the direction.
struct V2LibraryListHeader: View {
    let sort: CompactSort
    let onSort: (CompactSortColumn) -> Void
    @Environment(\.pagePalette) private var page

    var body: some View {
        HStack {
            head("Title", .title)
            Spacer()
            head("Size", .size)
                .padding(.trailing, 29)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background { V2ListRowSurface(first: true, last: false) }
    }

    private func head(_ title: String, _ column: CompactSortColumn) -> some View {
        let on = sort.column == column
        return Button { onSort(column) } label: {
            HStack(spacing: 4) {
                Text(title)
                if on { Image(systemName: sort.ascending ? "chevron.up" : "chevron.down").font(.system(size: 9, weight: .bold)) }
            }
            .font(.system(size: 11.5, weight: .semibold))
            .tracking(0.23)
            .foregroundStyle(on ? Theme.accentText : (page?.inkMuted ?? Theme.mut))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
