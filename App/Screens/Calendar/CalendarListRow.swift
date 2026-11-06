import SwiftUI
import FusionhaKit

// v2's Calendar list (plan S11, mock discover-cal.js `agenda`): one W1 card
// per day, a row per airing with a time column (or the movie's release
// glyph), the poster, title, sub line and the HD and 4K tickets in one
// ink. What is on air now carries the On air pill in the time column.

/// A day's airings on one card, hairlines between rows, today's now line
/// before the first still to come.
struct CalendarDayCard: View {
    let items: [CalendarDayItem]
    let isToday: Bool
    let now: Date
    @Environment(\.browseLook) private var look

    var body: some View {
        let nowIndex: Int? = isToday ? items.firstIndex { !$0.aired(now: now) } : nil
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index == nowIndex, index > 0 { PhoneNowLine().padding(.horizontal, 12) }
                if index > 0 && index != nowIndex { CalendarRowRule() }
                switch item {
                case .entry(let entry): CalendarListRow(entry: entry, now: now)
                case .run(let group): CalendarRunRow(group: group, now: now)
                }
            }
        }
        .browseCard(look, radius: 20)
    }
}

/// The hairline between two rows, from the title's edge.
struct CalendarRowRule: View {
    @Environment(\.pagePalette) private var page

    var body: some View {
        Rectangle()
            .fill((page?.ink ?? Theme.txt).opacity(0.09))
            .frame(height: 1)
            .padding(.leading, 118)
    }
}

/// One airing: time column, poster, title, sub line, tickets. Dimmed once aired.
struct CalendarListRow: View {
    let entry: CalendarEntry
    let now: Date
    @Environment(AppModel.self) private var model

    var body: some View {
        Button { model.open(entry.itemId) } label: {
            CalendarRowLayout(entry: entry, onAir: entry.isOnAir(now: now), time: entry.airStart(),
                              title: entry.title, sub: sub, tickets: CalendarTickets.of([entry]))
                .opacity(entry.hasAired(now: now) && !entry.isOnAir(now: now) ? 0.62 : 1)
        }
        .buttonStyle(SearchRowStyle())
        .accessibilityLabel("\(entry.title) · \(entry.label)\(entry.airTime().map { " · \($0)" } ?? "")")
    }

    private var sub: String {
        if entry.isMovie { return "\(entry.movieReleaseType?.label ?? "Release") release" }
        var parts = [entry.code]
        if let name = entry.episodeTitle, !name.isEmpty { parts.append(name) }
        if entry.isAnime { parts.append("Anime") }
        return parts.joined(separator: " · ")
    }
}

/// Two or more same-day episodes of one show: one row, "S1 E1–6 · season
/// drop, 6 episodes", tickets counting the episodes on disk.
struct CalendarRunRow: View {
    let group: SeasonGroup
    let now: Date
    @Environment(AppModel.self) private var model

    var body: some View {
        let n = group.entries.count
        Button { model.open(group.item.itemId) } label: {
            CalendarRowLayout(entry: group.item, onAir: group.entries.contains { $0.isOnAir(now: now) },
                              time: group.item.airStart(), title: group.item.title,
                              sub: "\(group.codes) · \(n >= 3 ? "season drop, " : "")\(n) episodes",
                              tickets: CalendarTickets.of(group.entries))
                .opacity(group.entries.allSatisfy { $0.hasAired(now: now) } ? 0.62 : 1)
        }
        .buttonStyle(SearchRowStyle())
        .accessibilityLabel("\(group.item.title) · \(n) episodes · \(group.codes)")
    }
}

/// The row's layout, shared by single airings and runs.
private struct CalendarRowLayout: View {
    let entry: CalendarEntry
    let onAir: Bool
    let time: String?
    let title: String
    let sub: String
    let tickets: (hd: EditionBadgeState?, uhd: EditionBadgeState?)
    @Environment(\.pagePalette) private var page

    private var inks: BrowseInks { BrowseInks(page: page) }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            timeColumn.frame(width: 52, alignment: .leading)
            PosterImage(url: TMDBImage.resized(entry.posterUrl ?? entry.backdropUrl, to: "w154"))
                .frame(width: 40, height: 60)
                .shelfPoster(radius: 6, shadow: false)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(inks.ink)
                    .lineLimit(1)
                Text(sub)
                    .font(.system(size: 12.5))
                    .foregroundStyle(inks.muted)
                    .lineLimit(1)
                EditionTicketPair(hd: tickets.hd, uhd: tickets.uhd)
                    .padding(.top, 3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(onAir ? Theme.primary.opacity(0.12) : .clear)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var timeColumn: some View {
        if onAir {
            CalendarOnAirPill()
        } else if entry.isMovie, let type = entry.movieReleaseType {
            Image(systemName: type.symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(inks.muted)
                .accessibilityLabel("\(type.label) release")
        } else if let time {
            Text(time)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(inks.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

/// "On air": the accent capsule with the live glyph (accent = active).
struct CalendarOnAirPill: View {
    var body: some View {
        Label("On air", systemImage: "dot.radiowaves.left.and.right")
            .labelStyle(.titleAndIcon)
            .font(.system(size: 10.5, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(Theme.primary, in: Capsule())
            .accessibilityLabel("On air now")
    }
}

/// The HD and 4K tickets for one airing or a run (the first version of
/// each tier; a run counts the episodes on disk).
enum CalendarTickets {
    static func of(_ entries: [CalendarEntry]) -> (hd: EditionBadgeState?, uhd: EditionBadgeState?) {
        (state(.hd, entries), state(.uhd, entries))
    }

    private static func state(_ tier: QualityTier, _ entries: [CalendarEntry]) -> EditionBadgeState? {
        let editions = entries.compactMap { entry in entry.editions.first { $0.tier == tier } }
        guard !editions.isEmpty else { return nil }
        if editions.count == 1 { return EditionBadgeState(status: editions[0].status) }
        let states = editions.map { EditionBadgeState(status: $0.status) }
        if states.contains(.held) { return .held }
        if states.contains(where: \.showsRing) { return .downloading(progress: nil) }
        let have = states.filter(\.isFilled).count
        if have == states.count { return .onDisk }
        return have == 0 ? .missing : .partial(have: have, of: states.count)
    }
}

extension CalendarEntry {
    /// On air now: from its air instant until its runtime (30 min if unknown) ends.
    func isOnAir(now: Date) -> Bool {
        guard !isMovie, let start = airDatetimeInstant else { return false }
        let minutes = runtime.flatMap { $0 > 0 ? $0 : nil } ?? 30
        return start <= now && now < start.addingTimeInterval(Double(minutes) * 60)
    }
}
