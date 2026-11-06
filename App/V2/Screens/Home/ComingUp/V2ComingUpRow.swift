import SwiftUI
import FusionhaKit

/// Home's "Coming up" (owner-approved Home mock, 2026-11-06): the header with
/// the preset menu (`V2ComingUpMenu`, "Mix"), then the centre-focus carousel
/// (`V2ComingUpCarousel`) of library titles with a release or airing in the
/// window. Wide (a page of 700 or more) the carousel takes the left column
/// and the focused title's detail the right (`V2ComingUpDetail`). The
/// calendar feed is read here (cached first, then every ten minutes); with
/// nothing in the window the row hides (Recently added sits right under it).
struct V2ComingUpRow: View {
    /// The page's width and side gutter.
    let width: CGFloat
    let gutter: CGFloat
    let wide: Bool
    /// Space above the row, only while it shows.
    var topGap: CGFloat = 0
    /// The focused card's art, for the page's ground (nil while hidden).
    @Binding var leadArt: URL?
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page
    @Environment(\.motionEnabled) private var motion
    @AppStorage(V2ComingUpSettings.kindsKey) private var kindsRaw = V2ComingUpSettings.defaultKinds
    @AppStorage(V2ComingUpSettings.daysKey) private var days = V2ComingUpSettings.defaultDays
    @State private var entries: [CalendarEntry]?
    @State private var cards: [V2ComingUpCard] = []
    @State private var focused: Int?

    private var window: Int { V2ComingUpSettings.window(days) }
    private var current: V2ComingUpCard? { cards.first { $0.id == focused } ?? cards.first }

    var body: some View {
        // A real container even while empty: its feed task must still run.
        VStack(alignment: .leading, spacing: 0) {
            if !cards.isEmpty {
                if wide {
                    V2HomePair {
                        VStack(alignment: .leading, spacing: 4) {
                            header
                            carousel(cardWidth: 197, showsMeta: false)
                        }
                    } trailing: {
                        if let current { V2ComingUpDetail(card: current).padding(.top, 64).padding(.leading, 16) }
                    }
                    .padding(.top, topGap)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        header.padding(.horizontal, gutter)
                        carousel(cardWidth: min(260, max(160, width - 140)), showsMeta: true)
                    }
                    .padding(.top, topGap)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(motion ? .snappy : nil, value: cards)
        .onChange(of: leadURL, initial: true) { _, url in leadArt = url }
        .task(id: window) { await feed() }
        .onChange(of: RebuildKey(entries: entries, kinds: kindsRaw, window: window, version: model.libraryVersion),
                  initial: true) { rebuild() }
    }

    private func carousel(cardWidth: CGFloat, showsMeta: Bool) -> some View {
        V2ComingUpCarousel(cards: cards, cardWidth: cardWidth, showsMeta: showsMeta, clips: wide, focused: $focused)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Coming up")
                .font(.system(size: 21, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(page?.ink ?? Theme.txt)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            V2ComingUpMenu(kindsRaw: $kindsRaw, days: $days)
        }
    }

    /// The focused card's art (nil while the row is hidden).
    private var leadURL: URL? {
        guard let item = current?.item else { return nil }
        return PageArtSource.url(backdrop: item.backdropUrl, poster: item.posterUrl)
    }

    private func rebuild() {
        guard let entries else { return }
        var titles: [Int: MediaItem] = [:]
        for item in model.library where (item.posterUrl ?? item.backdropUrl) != nil {
            titles[item.id] = item
        }
        let next = V2ComingUpPick.cards(entries, titles: titles, kinds: V2ComingUpSettings.decode(kindsRaw),
                                        days: window)
        if next != cards { cards = next }
        if let focused, !next.contains(where: { $0.id == focused }) { self.focused = nil }
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
        let version: Int
    }
}
