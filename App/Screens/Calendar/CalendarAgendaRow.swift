import SwiftUI
import FusionhaKit

/// `.ev`: a solid row on the ground. A lit 40×60 poster, title, the sub line
/// (`S05·E04 · Missing Persons`), and on the right the air time over the edition
/// rails (the library's, in its rail style). Dimmed once aired.
struct AgendaRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.railConsolidate) private var consolidate
    let entry: CalendarEntry
    let now: Date

    var body: some View {
        Button { model.open(entry.itemId) } label: {
            HStack(alignment: .center, spacing: 14) {
                PosterImage(url: TMDBImage.resized(entry.posterUrl ?? entry.backdropUrl, to: "w154"))
                    .frame(width: 40, height: 60)
                    .shelfPoster(radius: 5, shadow: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.txt)
                        .lineLimit(1)
                    AgendaSubLine(entry: entry)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 6) {
                    if let time = entry.isMovie ? nil : entry.airStart() {
                        Text(time)
                            .font(.system(size: 13, weight: .medium).monospacedDigit())
                            .foregroundStyle(Theme.mut)
                            .lineLimit(1)
                    }
                    CalRailStack(units: CalendarRails.entry(entry, now: now, consolidate: consolidate))
                }
                .fixedSize()
            }
            .padding(.vertical, 10)
            .opacity(entry.hasAired(now: now) ? 0.62 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.title) · \(entry.label)\(entry.airTime().map { " · \($0)" } ?? "")")
    }
}

/// The row's sub line: absolute number and code, episode name, the pink Anime
/// tag; a movie shows its release type (symbol and name in the legend's colour).
private struct AgendaSubLine: View {
    let entry: CalendarEntry

    private var parts: [String] {
        var out: [String] = []
        if entry.label != entry.code { out.append(entry.label) }
        out.append(entry.code)
        if let name = entry.episodeTitle, !name.isEmpty { out.append(name) }
        return out
    }

    var body: some View {
        HStack(spacing: 0) {
            if entry.isMovie {
                if let type = entry.movieReleaseType {
                    Image(systemName: type.symbol)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(type.color)
                        .padding(.trailing, 5)
                    Text("\(type.label) release").foregroundStyle(type.color)
                } else {
                    Text(entry.label).foregroundStyle(Theme.mut)
                }
            } else {
                Text(parts.joined(separator: " · "))
                    .foregroundStyle(Theme.mut)
                    .layoutPriority(-1)
                if entry.isAnime {
                    Text(" · Anime")
                        .foregroundStyle(Theme.anime)
                        .fixedSize()
                }
            }
        }
        .font(.system(size: 13))
        .lineLimit(1)
    }
}
