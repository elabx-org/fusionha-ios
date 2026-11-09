import SwiftUI
import FusionhaKit

/// The full timeline (owner 2026-11-09, option A), pushed from Home's "See
/// all" or a timeline's more row, on the page it was opened from: Recently
/// added (every title added in the last 30 days) or Recently arrived
/// (every import, newest first, more loading as it scrolls). Swipe between
/// the two; the title names the page and the page dots float at the
/// bottom in a small glass capsule. The day stays pinned while its rows
/// scroll under it.
struct V2RecentTimelinePage: View {
    let feed: V2ArrivalsFeed
    @Binding var page: V2TimelinePage
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    @State private var library: [Int: MediaItem] = [:]
    @State private var added: [V2TimelineEntry] = []
    @State private var arrived: [V2TimelineEntry] = []
    @State private var width: CGFloat = 0

    var body: some View {
        TabView(selection: $page) {
            list(.added).tag(V2TimelinePage.added)
            list(.arrived).tag(V2TimelinePage.arrived)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(motion ? .smooth(duration: 0.3) : nil, value: page)
        .overlay(alignment: .bottom) { dots }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .v2PageGround(art: groundArt)
        .shellPage(page.title)
        .sensoryFeedback(.selection, trigger: page)
        .onChange(of: model.libraryVersion, initial: true) { rebuildAdded() }
        .onChange(of: feed.rows, initial: true) { rebuildArrived() }
        .task { if feed.rows.isEmpty { await feed.refresh(model.client) } }
    }

    private var groundArt: URL? {
        let first = (page == .added ? added : arrived).first?.item
        return first.flatMap { PageArtSource.url(backdrop: $0.backdropUrl, poster: $0.posterUrl) }
    }

    private func list(_ p: V2TimelinePage) -> some View {
        let entries = p == .added ? added : arrived
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                V2TimelineCaption(text: subtitle(p, count: entries.count))
                    .padding(.bottom, 6)
                ForEach(V2TimelineEntries.days(entries)) { group in
                    Section {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(group.entries) { entry in
                                V2RecentTimelineRow(entry: entry, thumb: V2RecentRows.thumb(width), slot: V2RecentRows.slot)
                            }
                        }
                        .background(alignment: .topLeading) { V2TimelineSpine().padding(.top, -14) }
                    } header: {
                        V2TimelinePinnedDay(day: group.day)
                    }
                }
                if p == .arrived && feed.hasMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .task { await feed.loadMore(model.client) }
                }
                if entries.isEmpty {
                    V2TimelineCaption(text: p == .added ? "Nothing added in the last 30 days." : "Nothing imported yet.")
                        .padding(.vertical, 20)
                }
            }
            .padding(.bottom, Theme.pageBottom + 56)
        }
    }

    private func subtitle(_ p: V2TimelinePage, count: Int) -> String {
        switch p {
        case .added: return "Last 30 days · " + (count == 1 ? "1 title" : "\(count.formatted()) titles")
        case .arrived: return "Every import, newest first"
        }
    }

    private var dots: some View {
        V2CarouselDots(ids: V2TimelinePage.allCases.map(\.rawValue), current: page.rawValue)
            .fixedSize()
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .glassEffect(.regular, in: Capsule())
            .padding(.bottom, 12)
            .accessibilityHidden(true)
    }

    private func rebuildAdded() {
        library = Dictionary(model.library.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        added = V2TimelineEntries.added(V2TimelineEntries.lastMonth(model.library))
        rebuildArrived()
    }

    private func rebuildArrived() {
        arrived = V2TimelineEntries.arrived(feed.rows, library: library)
    }
}

/// A full-page day heading, pinned while its rows scroll under it.
struct V2TimelinePinnedDay: View {
    let day: String
    @Environment(\.pagePalette) private var page

    var body: some View {
        let tint = page?.tint ?? Theme.bg
        V2TimelineDayLabel(day: day)
            .padding(.bottom, 4)
            .background {
                LinearGradient(colors: [tint.opacity(0.92), tint.opacity(0.75), tint.opacity(0)],
                               startPoint: .top, endPoint: .bottom)
            }
    }
}

/// The page's muted line under the title, in the page's ink.
struct V2TimelineCaption: View {
    let text: String
    @Environment(\.pagePalette) private var page

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(page?.inkMuted ?? Theme.mut)
            .padding(.horizontal, 20)
    }
}
