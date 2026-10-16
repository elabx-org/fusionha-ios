import SwiftUI
import FusionhaKit

// MARK: Week cards
//
// Solid shelf objects (never glass): card fill, a hairline, lit posters. The four
// server card styles (landscape still, portrait poster, compact, tier accent)
// all stay; times are ink-2, never a generic cyan.

/// The shared card chrome: radius 14, hairline, card fill (tier-tinted for
/// `accent`), dimmed once aired, breathing while an edition is grabbing.
private struct WeekCardChrome: ViewModifier {
    let style: WeekCardStyle
    let tier: QualityTier
    let aired: Bool
    let live: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous)
        let accent = style == .accent
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(accent ? tier.color.opacity(0.12) : .clear, in: shape)
            .calLivePulse(live, shape: shape, base: Theme.card)
            .clipShape(shape)
            .overlay(shape.strokeBorder(accent ? tier.color.opacity(0.34) : Theme.line))
            .opacity(aired ? 0.55 : 1)
            .contentShape(shape)
    }
}

/// The time line of a card: ink-2, or the tier colour on `accent` cards.
private func weekTimeColor(_ style: WeekCardStyle, _ entry: CalendarEntry) -> Color {
    style == .accent ? entry.accentTier.color : Theme.mut
}

struct WeekEventCard: View {
    @Environment(AppModel.self) private var model
    let entry: CalendarEntry
    let style: WeekCardStyle
    let now: Date

    var body: some View {
        Button { model.open(entry.itemId) } label: {
            Group {
                if style == .landscape {
                    landscape
                } else {
                    poster
                }
            }
            .modifier(WeekCardChrome(style: style, tier: entry.accentTier, aired: entry.hasAired(now: now), live: entry.isGrabbing))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.title) · \(entry.label)\(entry.airTime().map { " · \($0)" } ?? "")")
    }

    private var landscape: some View {
        VStack(alignment: .leading, spacing: 0) {
            WeekStill(entry: entry)
            VStack(alignment: .leading, spacing: 4) {
                if let time = entry.airTime() {
                    Text(time)
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                        .foregroundStyle(Theme.mut)
                }
                Text(entry.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                WeekCardSub(entry: entry, leadingGlyph: false)
                CalRailWrap(entry: entry, now: now)
                    .padding(.top, 8)
            }
            .padding(.top, 10)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    private var poster: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                WeekPoster(entry: entry, style: style)
                VStack(alignment: .leading, spacing: 2) {
                    if let time = style == .compact ? entry.airStart() : entry.airTime() {
                        Text(time)
                            .font(style == .compact
                                  ? .system(size: 10, weight: .semibold, design: .monospaced)
                                  : .system(size: 13, weight: .medium).monospacedDigit())
                            .foregroundStyle(weekTimeColor(style, entry))
                    }
                    Text(entry.title).font(.system(size: style == .compact ? 15 : 17, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(2)
                    WeekCardSub(entry: entry, leadingGlyph: style == .portrait)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            CalRailWrap(entry: entry, now: now)
                .padding(.top, 10)
        }
        .padding(12)
    }
}

struct SeasonDropCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.railConsolidate) private var consolidate
    let group: SeasonGroup
    let style: WeekCardStyle
    let now: Date

    private var entry: CalendarEntry { group.item }
    private var count: Int { group.entries.count }
    private var timeLine: String {
        let timed = group.entries.contains { $0.airDatetime != nil }
        return timed ? (entry.airTime() ?? "Season") : "Season · all day"
    }
    private var season: String { entry.seasonNumber.map { "Season \($0)" } ?? "Season" }

    var body: some View {
        Button { model.open(entry.itemId) } label: {
            Group {
                if style == .landscape {
                    landscape
                } else {
                    poster
                }
            }
            .modifier(WeekCardChrome(style: style, tier: entry.accentTier, aired: false, live: false))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.title) · \(season) · \(count) episodes · season drop · \(timeLine)")
    }

    private var dropTag: some View {
        Text("◈ SEASON DROP")
            .font(.system(size: 9, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle(Theme.i2)
    }

    private var landscape: some View {
        VStack(alignment: .leading, spacing: 0) {
            WeekStill(entry: entry)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    dropTag
                    Text(timeLine)
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                        .foregroundStyle(Theme.mut)
                        .lineLimit(1)
                }
                Text(entry.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                HStack(spacing: 6) {
                    Text(season).fontWeight(.semibold).foregroundStyle(Theme.txt)
                    Text("\(count) episodes · season drop").foregroundStyle(Theme.mut).lineLimit(1)
                }
                .font(.system(size: 13))
                seasonRails.padding(.top, 8)
            }
            .padding(.top, 10)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    private var poster: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                WeekPoster(entry: entry, style: style)
                VStack(alignment: .leading, spacing: 2) {
                    dropTag
                    Text(timeLine)
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                        .foregroundStyle(weekTimeColor(style, entry))
                    Text(entry.title).font(.system(size: style == .compact ? 15 : 17, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(2)
                    HStack(spacing: 5) {
                        if style == .portrait {
                            LineGlyph(kind: LineGlyph.kind(for: entry), size: 13)
                        }
                        Text("\(season) · \(count) episodes")
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mut)
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            seasonRails.padding(.top, 10)
        }
        .padding(12)
    }

    private var seasonRails: some View {
        CalRails(units: CalendarRails.season(group, now: now, consolidate: consolidate))
    }
}
