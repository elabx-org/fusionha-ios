import SwiftUI
import FusionhaKit

// MARK: - Rails

/// Rail chrome: heading, count, own-line toggle, then the state or the track.
struct RailSection<Icon: View, Toggle: View, Track: View>: View {
    let title: String
    let count: String?
    @ViewBuilder var icon: Icon
    @ViewBuilder var toggle: Toggle
    @ViewBuilder var track: Track

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    HStack(spacing: 8) {
                        icon
                        Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
                    }
                    if let count {
                        Text(count).font(.system(size: 12)).foregroundStyle(Theme.dim)
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) { toggle }
                    .scrollClipDisabled()
            }
            .padding(.bottom, 14)
            track
        }
        .padding(.bottom, 34)
    }
}

enum RailLoad<T> {
    case loading, failed, loaded([T])
}

/// A titled horizontal rail of Discover posters.
struct DiscoverRail<Icon: View, Toggle: View>: View {
    @Environment(AppModel.self) private var model
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
            case .loaded(let items):
                RailTrack {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        DiscoverCard(result: item, trending: trending, canAdd: canAdd, canRequest: canRequest)
                            .frame(width: 116)
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

/// The horizontal track: gap 14, padding 2 2 12, snaps to cards.
struct RailTrack<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 14) { content }
                .scrollTargetLayout()
                .padding(.horizontal, 2)
                .padding(.top, 2)
                .padding(.bottom, 12)
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
        .scrollClipDisabled()
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
