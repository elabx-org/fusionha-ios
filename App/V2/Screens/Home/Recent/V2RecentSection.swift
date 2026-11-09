import SwiftUI
import FusionhaKit

/// Home's timeline section (owner 2026-11-09, option A): two pages side by
/// side, Recently added (titles that joined the library) and Recently
/// arrived (titles that had something imported, per day). Swipe between
/// them; the heading names the page and page dots sit under the timeline,
/// as under Coming up. Four rows on the phone and the folded Duo (the
/// timeline, ending in a "N more ›" row), six as the zipper wide. "See
/// all" and the more row open the full page on the page shown. With no
/// imports the section is Recently added alone, as before.
struct V2RecentSection: View {
    let data: V2HomeData
    let arrived: [V2TimelineEntry]
    let width: CGFloat
    let gutter: CGFloat
    let wide: Bool
    @Binding var page: V2TimelinePage
    let seeAll: (V2TimelinePage) -> Void
    @Environment(\.motionEnabled) private var motion
    @State private var scrolled: Int?

    private var limit: Int { wide ? 6 : 4 }
    private var pages: [V2TimelinePage] { arrived.isEmpty ? [.added] : V2TimelinePage.allCases }
    private var current: V2TimelinePage { pages.contains(page) ? page : .added }

    var body: some View {
        if !data.recent.isEmpty {
            VStack(alignment: .leading, spacing: wide ? 14 : 4) {
                head.padding(.horizontal, wide ? 0 : gutter)
                if pages.count > 1 { pager } else { timeline(.added) }
                if pages.count > 1 {
                    V2CarouselDots(ids: pages.map(\.rawValue), current: current.rawValue)
                        .padding(.top, wide ? 0 : 8)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityActions {
                if pages.count > 1 {
                    let other: V2TimelinePage = current == .added ? .arrived : .added
                    Button("Show \(other.title.lowercased())") { show(other) }
                }
            }
        }
    }

    private var head: some View {
        let count = current == .added && data.recentCount > 0 ? " \(data.recentCount.formatted())" : ""
        return V2HomeSectionHead(title: current.title, action: "See all" + count,
                                 accessibilityAction: "See all \(current.title.lowercased())") { seeAll(current) }
            .contentTransition(.opacity)
            .animation(motion ? .smooth(duration: 0.25) : nil, value: current)
    }

    private var pager: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(pages) { p in
                    timeline(p)
                        .containerRelativeFrame(.horizontal)
                        .id(p.rawValue)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrolled)
        .onAppear { if scrolled == nil { scrolled = current.rawValue } }
        .onChange(of: scrolled) { _, next in
            if let next, let p = V2TimelinePage(rawValue: next), p != page { page = p }
        }
        .onChange(of: page) { _, next in
            if scrolled != next.rawValue { scrolled = next.rawValue }
        }
        .sensoryFeedback(.selection, trigger: current)
    }

    @ViewBuilder
    private func timeline(_ p: V2TimelinePage) -> some View {
        let entries = p == .added ? V2TimelineEntries.added(Array(data.recent.prefix(limit)))
                                  : Array(arrived.prefix(limit))
        if wide {
            V2RecentZipper(entries: entries)
        } else {
            V2RecentRows(entries: entries, width: width, more: more(p, shown: entries))
        }
    }

    private func more(_ p: V2TimelinePage, shown: [V2TimelineEntry]) -> (label: String, open: () -> Void)? {
        let open: () -> Void = { seeAll(p) }
        switch p {
        case .added:
            let rest = data.recentCount - shown.count
            guard rest > 0 else { return nil }
            return (label: "\(rest.formatted()) more this month", open: open)
        case .arrived:
            let rest = arrived.count - shown.count
            guard rest > 0, let last = arrived.last else { return nil }
            return (label: "\(rest.formatted()) more since \(V2RecentWords.since(last.date))", open: open)
        }
    }

    /// VoiceOver's action; Reduce Motion pages without the slide.
    private func show(_ p: V2TimelinePage) {
        withAnimation(motion ? .smooth(duration: 0.35) : nil) { page = p }
    }
}
