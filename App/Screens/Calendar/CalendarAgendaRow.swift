import SwiftUI
import FusionhaKit

/// `.ev`: a solid row on the ground. A lit 40×60 poster, title, the sub line
/// (`S05·E04 · Missing Persons`), and on the right the air time over the edition
/// chips with their status. Dimmed once aired.
struct AgendaRow: View {
    @Environment(AppModel.self) private var model
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
                    CalEditionMarks(entry: entry, now: now)
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

/// The edition chips of `.ev-r .eds`: each lit HD / 4K chip (`TierPill`) paired
/// with its status mark, coloured by status: ✓ on disk, ↓ grabbing, `wanted`,
/// `soon` when unaired.
struct CalEditionMarks: View {
    let entry: CalendarEntry
    let now: Date

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(entry.editions.enumerated()), id: \.offset) { _, edition in
                let key = entry.statusKey(for: edition, now: now)
                HStack(spacing: 4) {
                    TierPill(tier: edition.tier)
                    mark(key, progress: edition.progress)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(key.color)
                        .lineLimit(1)
                        .fixedSize()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(edition.tier.chipLabel) \(key.label)\(key == .downloading ? edition.progress.map { ", \($0) percent" } ?? "" : "")")
            }
        }
    }

    @ViewBuilder
    private func mark(_ key: CalendarStatusKey, progress: Int?) -> some View {
        switch key {
        case .downloaded:
            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
        case .downloading:
            Text(progress.map { "↓ \(min(max($0, 0), 100))%" } ?? "↓")
        case .missing:
            Text("wanted")
        case .unaired:
            Text("soon")
        }
    }
}
