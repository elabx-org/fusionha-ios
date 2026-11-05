import SwiftUI
import FusionhaKit

/// The Library home's "Coming up" row, in place of the old hero picks: a
/// header with the preset menu (`V2ComingUpMenu`), then the hero carousel
/// of library titles with a release or airing in the window, each card
/// saying why. Nothing matching falls back to Recently added. The calendar
/// feed is read here (cached first, then every ten minutes) so the row
/// carries its own data; until the first answer it holds its place unseen.
struct V2ComingUpRow: View {
    /// The titles the Library's filters leave.
    let visibleIds: [Int]
    /// The fallback: Recently added, newest first.
    let recent: [MediaItem]
    let width: CGFloat
    let gutter: CGFloat
    /// The lead card's art, for the page's ground (nil until the feed answers).
    @Binding var leadArt: URL?
    /// True while the row shows Recently added in place of Coming up.
    @Binding var fallingBack: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page
    @Environment(\.motionEnabled) private var motion
    @AppStorage(V2ComingUpSettings.kindsKey) private var kindsRaw = V2ComingUpSettings.defaultKinds
    @AppStorage(V2ComingUpSettings.daysKey) private var days = V2ComingUpSettings.defaultDays
    @State private var entries: [CalendarEntry]?
    @State private var cards: [V2ComingUpCard] = []

    private var window: Int { V2ComingUpSettings.window(days) }
    private var fallback: [MediaItem] {
        Array(recent.filter { ($0.backdropUrl ?? $0.posterUrl) != nil }.prefix(V2ComingUpPick.limit))
    }

    var body: some View {
        let coming = !cards.isEmpty
        let items = coming ? cards.map(\.item) : fallback
        VStack(alignment: .leading, spacing: 12) {
            if !items.isEmpty {
                header(coming ? "Coming up" : "Recently added")
                V2LibraryHeroCarousel(items: items, width: width, gutter: gutter,
                                      notes: coming ? Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0.reason) }) : [:])
                    .id(coming)
            }
        }
        .opacity(entries == nil ? 0 : 1)
        .animation(motion ? .easeOut(duration: 0.25) : nil, value: entries == nil)
        .animation(motion ? .snappy : nil, value: cards)
        .onChange(of: leadURL(items), initial: true) { _, url in leadArt = url }
        .onChange(of: entries != nil && !coming && !items.isEmpty, initial: true) { _, on in fallingBack = on }
        .task(id: window) { await feed() }
        .onChange(of: RebuildKey(entries: entries, kinds: kindsRaw, window: window, ids: visibleIds,
                                 version: model.libraryVersion), initial: true) { rebuild() }
    }

    private func header(_ title: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.system(size: 21, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(page?.ink ?? Theme.txt)
                .accessibilityAddTraits(.isHeader)
                .contentTransition(.opacity)
            Spacer(minLength: 8)
            V2ComingUpMenu(kindsRaw: $kindsRaw, days: $days)
        }
    }

    /// The first card's art once the feed has answered (the row is unseen before).
    private func leadURL(_ items: [MediaItem]) -> URL? {
        guard entries != nil, let first = items.first else { return nil }
        return PageArtSource.url(backdrop: first.backdropUrl, poster: first.posterUrl)
    }

    private func rebuild() {
        guard let entries else { return }
        let ids = Set(visibleIds)
        var titles: [Int: MediaItem] = [:]
        for item in model.library where ids.contains(item.id) && (item.backdropUrl ?? item.posterUrl) != nil {
            titles[item.id] = item
        }
        let next = V2ComingUpPick.cards(entries, titles: titles, kinds: V2ComingUpSettings.decode(kindsRaw),
                                        days: window)
        if next != cards { cards = next }
    }

    /// Today − 1 (a network's air date can trail the viewer's day) to the
    /// window's end + 1; the last answer this phone saw comes first.
    private func feed() async {
        guard let client = model.client else {
            if entries == nil { entries = [] }
            return
        }
        let cal = Calendar.current
        let today = CalendarMath.iso(Date(), cal)
        let from = CalendarMath.shift(today, days: -1, cal)
        let to = CalendarMath.shift(today, days: window + 1, cal)
        if entries == nil, let kept = await client.cached({ try await $0.calendar(startISO: from, endISO: to) }) {
            entries = kept
        }
        while !Task.isCancelled {
            do {
                let next = try await client.calendar(startISO: from, endISO: to)
                if next != entries { entries = next } else { rebuild() }
            } catch is CancellationError {
                return
            } catch {
                if entries == nil { entries = [] }
            }
            try? await Task.sleep(for: .seconds(600))
        }
    }

    private struct RebuildKey: Equatable {
        let entries: [CalendarEntry]?
        let kinds: String
        let window: Int
        let ids: [Int]
        let version: Int
    }
}
