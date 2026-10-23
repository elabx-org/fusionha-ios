import SwiftUI
import FusionhaKit

// MARK: - Rails

/// Rail chrome: heading, count, own-line toggle, then the state or the track.
/// While Browse spans a Spread the heading is on the left page and the toggle
/// on the right (Trending's Today / This Week, the owner's mock).
struct RailSection<Icon: View, Toggle: View, Track: View>: View {
    @Environment(\.spread) private var spread
    let title: String
    let count: String?
    @ViewBuilder var icon: Icon
    @ViewBuilder var toggle: Toggle
    @ViewBuilder var track: Track

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if spread.spans {
                    FoldSpanRow(spacing: 8) { heading } trailing: { toggleRow }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        heading
                        toggleRow
                    }
                }
            }
            .padding(.bottom, 14)
            track
        }
        .padding(.bottom, 34)
    }

    private var heading: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            HStack(spacing: 8) {
                icon
                Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
            }
            if let count {
                Text(count).font(.system(size: 12)).foregroundStyle(Theme.dim)
            }
        }
    }

    private var toggleRow: some View {
        ScrollView(.horizontal, showsIndicators: false) { toggle }
            .scrollClipDisabled()
    }
}

enum RailLoad<T> {
    case loading, failed, loaded([T])
}

/// A titled horizontal rail of Discover posters.
struct DiscoverRail<Icon: View, Toggle: View>: View {
    @Environment(AppModel.self) private var model
    @Environment(\.paneSize) private var pane
    @Environment(\.spread) private var spread
    /// The web's `.cell`: 116 on phones, 128 to 720, 158 on desktop; a page's
    /// while Browse spans a Spread.
    private var cellWidth: CGFloat {
        CGFloat(DiscoverFold.railCell(paneWidth: Double(pane.width), spanPage: spread.spanPageWidth))
    }
    /// Trending in a Spread: a grid, 6 across spanning both pages and the left
    /// page's columns once a title is open (the owner's mock), so the tapped
    /// title stays in view, outlined.
    private var asGrid: Bool { trending && spread.isActive }
    @Environment(DiscoverStore.self) private var store
    let title: String
    /// Changes when the rail must refetch (kind, window, monetization).
    let key: String
    let trending: Bool
    let canAdd: Bool
    let canRequest: Bool
    @ViewBuilder var icon: Icon
    @ViewBuilder var toggle: Toggle
    let load: (APIClient) async throws -> [MediaSearchResult]
    @State private var state: RailLoad<MediaSearchResult> = .loading

    var body: some View {
        RailSection(title: title, count: count) { icon } toggle: { toggle } track: {
            switch state {
            case .loading: RailStateLine(text: "Loading…")
            case .failed: RailStateLine(text: "Could not load this rail.", error: true)
            case .loaded(let items) where items.isEmpty: RailStateLine(text: "No titles right now.")
            case .loaded(let items) where asGrid:
                AdaptivePosterGrid {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        DiscoverCard(result: item, trending: trending, canAdd: canAdd, canRequest: canRequest)
                            .discoverReveal(index: index, step: 0.02)
                    }
                }
            case .loaded(let items):
                RailTrack(count: items.count, cell: cellWidth) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        DiscoverCard(result: item, trending: trending, canAdd: canAdd, canRequest: canRequest)
                            .railCell(cellWidth)
                            .discoverReveal(index: index)
                    }
                }
            }
        }
        .task(id: key) {
            guard let client = model.client else { return }
            if case .loaded = state {} else {
                // The rail as this phone last saw it, at once (the web's query cache).
                if let kept = await client.cached({ try await load($0) }), !kept.isEmpty {
                    state = .loaded(kept)
                } else {
                    state = .loading
                }
            }
            do {
                state = .loaded(try await load(client))
            } catch is CancellationError {
            } catch {
                store.railFailed(error)
                state = .failed
            }
        }
    }

    private var count: String? {
        guard case .loaded(let items) = state else { return nil }
        return items.count == 1 ? "1 title" : "\(items.count) titles"
    }
}

extension DiscoverRail where Toggle == EmptyView {
    init(title: String, key: String, trending: Bool, canAdd: Bool, canRequest: Bool,
         @ViewBuilder icon: () -> Icon, load: @escaping (APIClient) async throws -> [MediaSearchResult]) {
        self.init(title: title, key: key, trending: trending, canAdd: canAdd, canRequest: canRequest,
                  icon: icon, toggle: { EmptyView() }, load: load)
    }
}

extension View {
    /// Cards stagger in (0.026s each), not under Reduce DiscoverMotion.
    func discoverReveal(index: Int, step: Double = 0.026) -> some View {
        modifier(DiscoverRevealIn(delay: Double(min(index, 12)) * step))
    }
}

struct DiscoverRevealIn: ViewModifier {
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(DiscoverMotion.reduced(reduceMotion) || shown ? 1 : 0)
            .offset(y: DiscoverMotion.reduced(reduceMotion) || shown ? 0 : 12)
            .onAppear {
                guard !DiscoverMotion.reduced(reduceMotion), !shown else { return }
                withAnimation(DiscoverMotion.reveal().delay(delay)) { shown = true }
            }
    }
}

struct TrendingRail: View {
    let kind: SearchKind
    let canAdd: Bool
    let canRequest: Bool
    @State private var window = "week"

    var body: some View {
        let kind = self.kind
        let window = self.window
        DiscoverRail(title: "Trending", key: "trending|\(kind.rawValue)|\(window)", trending: true,
                     canAdd: canAdd, canRequest: canRequest) {
            Image(systemName: "flame").font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.anime)
        } toggle: {
            DiscoverSegmented(options: [("day", "Today"), ("week", "This Week")], selection: $window)
        } load: { client in
            try await client.discover(kind: kind, list: .trending, window: window, monetization: nil)
        }
    }
}

struct PopularRail: View {
    let kind: SearchKind
    let canAdd: Bool
    let canRequest: Bool
    @State private var monetization: DiscoverMonetization = .streaming

    var body: some View {
        let kind = self.kind
        let monetization = self.monetization
        DiscoverRail(title: "What's Popular", key: "popular|\(kind.rawValue)|\(monetization.rawValue)", trending: false,
                     canAdd: canAdd, canRequest: canRequest) {
            EmptyView()
        } toggle: {
            DiscoverSegmented(options: DiscoverMonetization.allCases.map { ($0, $0.title) }, selection: $monetization)
        } load: { client in
            try await client.discover(kind: kind, list: .popular, window: nil, monetization: monetization)
        }
    }
}
