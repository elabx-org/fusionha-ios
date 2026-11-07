import SwiftUI
import FusionhaKit

/// Recently added on the phone and the folded Duo (Home mock): a timeline
/// with its spine down the left edge, day headings, and compact rows (a
/// 16:9 backdrop thumb, the title, its note and the HD/4K tickets).
struct V2RecentRows: View {
    let items: [MediaItem]
    let width: CGFloat
    @Environment(\.pagePalette) private var page

    /// The spine's centre from the page's leading edge (mock: 31).
    static let spineX: CGFloat = 31
    private static let slot: CGFloat = 44

    private var thumb: CGFloat { min(150, max(128, (width * 0.32).rounded())) }

    var body: some View {
        let ink = page?.ink ?? Theme.txt
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                let day = V2RecentWords.day(V2RecentWords.added(item))
                if i == 0 || V2RecentWords.day(V2RecentWords.added(items[i - 1])) != day {
                    Text(day.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(page?.inkMuted ?? Theme.mut)
                        .padding(.leading, Self.slot + 12)
                        .padding(.top, 10)
                        .padding(.bottom, 2)
                }
                V2RecentTimelineRow(item: item, thumb: thumb, slot: Self.slot)
            }
        }
        .padding(.top, 8)
        .background(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 1)
                .fill(ink.opacity(0.18))
                .frame(width: 2)
                .padding(.top, 14)
                .padding(.bottom, 20)
                .offset(x: Self.spineX - 1)
        }
    }
}

/// One timeline row: the spine's dot, the thumb, the words.
struct V2RecentTimelineRow: View {
    let item: MediaItem
    let thumb: CGFloat
    let slot: CGFloat
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page
    @Environment(\.motionEnabled) private var motion
    @State private var shown = false

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
                    Text(V2RecentWords.note(item))
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
