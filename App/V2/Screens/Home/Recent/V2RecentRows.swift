import SwiftUI
import FusionhaKit

/// Home's timelines on the phone and the folded Duo (Home mock): the spine
/// down the left edge, day headings, and compact rows (a 16:9 backdrop
/// thumb, the title, its note and the HD/4K tickets). `more` ends it with
/// a row on the spine ("27 more this month ›") that opens the full page.
struct V2RecentRows: View {
    let entries: [V2TimelineEntry]
    let width: CGFloat
    var more: (label: String, open: () -> Void)?

    /// The spine's centre from the page's leading edge (mock: 31).
    static let spineX: CGFloat = 31
    static let slot: CGFloat = 44

    static func thumb(_ width: CGFloat) -> CGFloat { min(150, max(128, (width * 0.32).rounded())) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { i, entry in
                if i == 0 || entries[i - 1].day != entry.day {
                    V2TimelineDayLabel(day: entry.day)
                }
                V2RecentTimelineRow(entry: entry, thumb: Self.thumb(width), slot: Self.slot)
            }
            if let more {
                V2TimelineMoreRow(label: more.label, open: more.open)
            }
        }
        .padding(.top, 8)
        .background(alignment: .topLeading) { V2TimelineSpine() }
    }
}

/// A day heading on the spine's right ("TODAY", "SAT", "3 NOV").
struct V2TimelineDayLabel: View {
    let day: String
    @Environment(\.pagePalette) private var page

    var body: some View {
        Text(day.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(page?.inkMuted ?? Theme.mut)
            .padding(.leading, V2RecentRows.slot + 12)
            .padding(.top, 10)
            .padding(.bottom, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The timeline's spine, behind its rows.
struct V2TimelineSpine: View {
    @Environment(\.pagePalette) private var page

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill((page?.ink ?? Theme.txt).opacity(0.18))
            .frame(width: 2)
            .padding(.top, 14)
            .padding(.bottom, 20)
            .offset(x: V2RecentRows.spineX - 1)
    }
}

/// The timeline's last row: a small dot on the spine and a capsule
/// naming what else there is.
struct V2TimelineMoreRow: View {
    let label: String
    let open: () -> Void
    @Environment(\.pagePalette) private var page

    var body: some View {
        let ink = page?.ink ?? Theme.txt
        Button(action: open) {
            HStack(spacing: 12) {
                ZStack(alignment: .leading) {
                    Color.clear.frame(width: V2RecentRows.slot, height: 8)
                    Circle().fill(ink.opacity(0.7)).frame(width: 8, height: 8)
                        .offset(x: V2RecentRows.spineX - 4)
                }
                HStack(spacing: 4) {
                    Text(label).monospacedDigit()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).opacity(0.6)
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(ink.opacity(0.11)))
                .overlay(Capsule().strokeBorder(ink.opacity(0.25), lineWidth: 0.5))
                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            .padding(.bottom, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// One timeline row: the spine's dot, the thumb, the words.
struct V2RecentTimelineRow: View {
    let entry: V2TimelineEntry
    let thumb: CGFloat
    let slot: CGFloat
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page
    @Environment(\.motionEnabled) private var motion
    @State private var shown = false

    private var item: MediaItem { entry.item }

    var body: some View {
        let ink = page?.ink ?? Theme.txt
        Button { model.open(item.id) } label: {
            HStack(spacing: 12) {
                ZStack(alignment: .leading) {
                    Color.clear.frame(width: slot, height: 12)
                    Circle()
                        .fill(ink)
                        .frame(width: 12, height: 12)
                        .background(Circle().fill(ink.opacity(0.12)).padding(-4))
                        .offset(x: V2RecentRows.spineX - 6)
                }
                V2BackdropThumb(item: item, width: thumb, radius: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .semibold))
                        .tracking(-0.2)
                        .foregroundStyle(ink)
                    Text(entry.note)
                        .font(.system(size: 13))
                        .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    V2ItemTickets(item: item).padding(.top, 4)
                }
                .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .padding(.trailing, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: motion && !shown ? -18 : 0)
        .onScrollVisibilityChange(threshold: 0.25) { visible in
            guard visible, !shown else { return }
            withAnimation(motion ? .smooth(duration: 0.6) : nil) { shown = true }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A title's 16:9 backdrop (its poster when it has none), cached and clean.
struct V2BackdropThumb: View {
    let item: MediaItem
    let width: CGFloat
    var radius: CGFloat = 18

    var body: some View {
        let size = CGSize(width: width, height: (width * 9 / 16).rounded())
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        PosterImage(url: TMDBImage.resized(item.backdropUrl ?? item.posterUrl, to: width > 200 ? "w780" : "w300"),
                    size: size)
            .frame(width: size.width, height: size.height)
            .clipShape(shape)
            .overlay(shape.strokeBorder(.white.opacity(0.08)))
            .shadow(color: .black.opacity(0.3), radius: 8, y: 6)
    }
}
