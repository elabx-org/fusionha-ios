import SwiftUI
import FusionhaKit

// The web's phone cards (`calendar/mobile/MobileCard`, `MobileRun`): solid
// content, never glass. Status reads as a static ambient wash, never a border.

extension CalendarWash {
    var color: Color { self == .grab ? Theme.grab : Theme.miss }
    var mono: MonoToken { self == .grab ? .grab : .miss }
}

/// The 44×66 poster of a phone card (clean art, no text on it).
private struct PhonePoster: View {
    let entry: CalendarEntry

    var body: some View {
        PosterImage(url: TMDBImage.resized(entry.posterUrl ?? entry.backdropUrl, to: "w154"))
            .frame(width: 44, height: 66)
            .shelfPoster(radius: 6, shadow: false)
    }
}

/// `MobileCard`: poster, time (or "All day" for a movie), the full title (wraps),
/// `code · episode name · Anime`, then the inline coverage rails.
struct PhoneCalCard: View {
    @Environment(AppModel.self) private var model
    let entry: CalendarEntry
    let now: Date

    private var time: String? { entry.airTime() ?? (entry.isMovie ? "All day" : nil) }

    var body: some View {
        let wash = entry.wash(now: now)
        Button { model.open(entry.itemId) } label: {
            HStack(alignment: .top, spacing: 11) {
                PhonePoster(entry: entry)
                VStack(alignment: .leading, spacing: 0) {
                    if let time {
                        Text(time)
                            .font(.system(size: 12, weight: .bold).monospacedDigit())
                            .foregroundStyle(Theme.grab)
                    }
                    Text(entry.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.txt)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 1)
                    subLine.padding(.top, 2)
                    CalRailWrap(entry: entry, now: now, rowGap: 6, columnGap: 14)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .actWash(wash?.color, mono: wash?.mono, radius: 14, border: .clear)
            .opacity(entry.hasAired(now: now) ? 0.62 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.title) · \(entry.label)\(time.map { " · \($0)" } ?? "")")
    }

    private var subLine: some View {
        let name = !entry.isMovie ? entry.episodeTitle.flatMap { $0.isEmpty ? nil : $0 } : nil
        return (Text(entry.label).fontWeight(.bold).foregroundColor(Theme.txt)
            + Text(name.map { " · \($0)" } ?? "").foregroundColor(Theme.mut)
            + Text(entry.isAnime ? " · Anime" : "").foregroundColor(Theme.mut))
            .font(.system(size: 12).monospacedDigit())
            .lineLimit(1)
    }
}

/// `MobileRun`: 2+ same-day episodes of one show as one card plus the first
/// episode line; the rest fold behind "+N more episodes of X".
struct PhoneCalRun: View {
    @Environment(AppModel.self) private var model
    @Environment(\.railConsolidate) private var consolidate
    @Environment(\.calMotionOff) private var motionOff
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let group: SeasonGroup
    let now: Date
    @State private var open = false

    private var first: CalendarEntry { group.item }
    private var rest: [CalendarEntry] { Array(group.entries.dropFirst()) }

    var body: some View {
        VStack(spacing: 0) {
            Button { model.open(first.itemId) } label: { head }
                .buttonStyle(.plain)
            PhoneEpisodeLine(entry: first, now: now)
            if open {
                ForEach(Array(rest.enumerated()), id: \.offset) { _, entry in
                    PhoneEpisodeLine(entry: entry, now: now)
                }
            }
            moreButton
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var head: some View {
        let n = group.entries.count
        return HStack(alignment: .top, spacing: 11) {
            PhonePoster(entry: first)
            VStack(alignment: .leading, spacing: 0) {
                Text("◆ \(n >= 3 ? "Season drop · " : "")\(n) episodes")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.66)
                    .textCase(.uppercase)
                    .foregroundStyle(QualityTier.uhd.color)
                if let span = group.span() {
                    Text(span)
                        .font(.system(size: 12, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.grab)
                }
                Text(first.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.txt)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 1)
                Text(group.codes)
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.txt)
                    .padding(.top, 2)
                CalRails(units: CalendarRails.season(group, now: now, consolidate: consolidate), rowGap: 6, columnGap: 14)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .opacity(group.entries.allSatisfy { $0.hasAired(now: now) } ? 0.62 : 1)
        .contentShape(Rectangle())
        .accessibilityLabel("\(first.title) · \(n) episodes · \(group.codes)")
    }

    private var moreButton: some View {
        Button {
            withAnimation(motionOff || reduceMotion ? nil : .easeOut(duration: 0.2)) { open.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text(open ? "Show less" : "+\(rest.count) more episode\(rest.count > 1 ? "s" : "") of \(first.title)")
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .rotationEffect(.degrees(open ? 180 : 0))
            }
            .font(.system(size: 12.5, weight: .bold))
            .foregroundStyle(Theme.accentText)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        .sensoryFeedback(.selection, trigger: open)
        .accessibilityAddTraits(open ? .isSelected : [])
    }
}

/// `EpisodeLine`: code, episode name, one status dot per edition.
private struct PhoneEpisodeLine: View {
    let entry: CalendarEntry
    let now: Date

    var body: some View {
        HStack(spacing: 10) {
            Text(entry.label)
                .font(.system(size: 12.5, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.txt)
            Text(entry.episodeTitle ?? "")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.mut)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) {
                ForEach(Array(entry.editions.enumerated()), id: \.offset) { _, edition in
                    Circle().fill(entry.statusKey(for: edition, now: now).color).frame(width: 7, height: 7)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(.leading, 65)
        .padding(.trailing, 12)
        .frame(minHeight: 44)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}
