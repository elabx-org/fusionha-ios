import SwiftUI
import FusionhaKit

/// Home's "Coming up" (owner-approved Home mock, 2026-11-06): the header with
/// the preset menu (`V2ComingUpMenu`, "Mix"), then the centre-focus carousel
/// (`V2ComingUpCarousel`) of library titles with a release or airing in the
/// window. Wide and flat (a page of 700 or more: the open Duo, an iPad)
/// Coming up is the page's hero across its whole width
/// (`V2ComingUpWideCarousel`, Posters or Backdrops by `V2ComingUpWideStyle`).
/// In book pose it keeps the split at the fold: the carousel on the left
/// page, the focused title's detail on the right (`V2ComingUpDetail`). The
/// calendar feed is read here (cached first, then every ten minutes); with
/// nothing in the window the row hides (Recently added sits right under it).
struct V2ComingUpRow: View {
    /// The page's width and side gutter.
    let width: CGFloat
    let gutter: CGFloat
    let wide: Bool
    /// Space above the row, only while it shows.
    var topGap: CGFloat = 0
    /// Kept clear at the heading's trailing end (the Duo's column, when the
    /// page runs under it), so the menu isn't under the clock.
    var headTrailing: CGFloat = 0
    /// The focused card's art, for the page's ground (nil while hidden).
    @Binding var leadArt: URL?
    /// Tabletop (half folded, the fold side to side): the row lays Home's whole
    /// page across both halves (`V2HomeTabletop`), or the plain page when
    /// there is nothing coming up. Nil everywhere else.
    var tabletop: V2TabletopContext?
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page
    @Environment(\.motionEnabled) private var motion
    @Environment(\.bookPose) private var bookPose
    @AppStorage(V2ComingUpWideStyle.key) private var wideRaw = V2ComingUpWideStyle.posters.rawValue
    @AppStorage(V2ComingUpSettings.kindsKey) private var kindsRaw = V2ComingUpSettings.defaultKinds
    @AppStorage(V2ComingUpSettings.daysKey) private var days = V2ComingUpSettings.defaultDays
    @State private var entries: [CalendarEntry]?
    @State private var cards: [V2ComingUpCard] = []
    @State private var focused: Int?
    /// The card to open on, until the carousel has moved there (once).
    @State private var opening: Int?
    @State private var opened = false
    /// The focused card across the fold: folded and open Home are two rows,
    /// so the new one opens on the card the other had (−1 = none yet).
    @SceneStorage("v2.home.comingUpFocus") private var keptFocus = -1
    /// The same, timed (`FoldAnchorLog`, per window): the resize that swaps
    /// the rows can re-centre the old one on its first card just before it
    /// goes, so the new row opens on the card focused before the resize.
    @Environment(\.foldKeep) private var foldKeep
    @State private var bornAt = ProcessInfo.processInfo.systemUptime

    /// Wide and flat (one panel): Coming up spans the page.
    @Environment(\.screenCentreSkew) private var skew
    private var hero: Bool { wide && !bookPose }
    private var window: Int { V2ComingUpSettings.window(days) }
    private var current: V2ComingUpCard? { cards.first { $0.id == focused } ?? cards.first }

    var body: some View {
        Group {
            if let tabletop { tabletopBody(tabletop) } else { inline }
        }
        .animation(motion ? .snappy : nil, value: cards)
        // The page's ground follows the focused card once the swipe settles:
        // set on every card passing the centre, it rebuilt the whole Home and
        // re-blurred the ground several times a second, and a long swipe lagged.
        .task(id: leadURL) {
            if leadArt != nil, leadURL != nil {
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
            }
            if leadArt != leadURL { leadArt = leadURL }
        }
        .onChange(of: focused) {
            guard let focused, opening == nil, Self.forcedOpening == nil else { return }
            keptFocus = focused
            focusLog?.record(AnyHashable(focused))
        }
        .task(id: window) { await feed() }
        .onChange(of: RebuildKey(entries: entries, kinds: kindsRaw, window: window, version: model.libraryVersion),
                  initial: true) { rebuild() }
    }

    /// Tabletop: the stage and the bottom half with cards, else Home as usual.
    @ViewBuilder
    private func tabletopBody(_ context: V2TabletopContext) -> some View {
        if let current {
            V2HomeTabletop(space: context.space, cards: cards, current: current, focused: $focused, opening: $opening,
                           kindsRaw: $kindsRaw, days: $days, rest: context.rest)
        } else {
            context.plain
        }
    }

    private var inline: some View {
        // A real container even while empty: its feed task must still run.
        VStack(alignment: .leading, spacing: 0) {
            if !cards.isEmpty {
                if hero {
                    VStack(alignment: .leading, spacing: 4) {
                        header.padding(.trailing, headTrailing)
                        V2ComingUpWideCarousel(cards: cards, style: V2ComingUpWideStyle(stored: wideRaw),
                                               focused: $focused, opening: $opening)
                    }
                    .padding(.top, topGap)
                } else if wide {
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
                        header.padding(.horizontal, gutter).padding(.trailing, headTrailing)
                        // Centred on the screen, not left of the folded Duo's column.
                        carousel(cardWidth: min(260, max(160, width - 140)), showsMeta: true)
                            .centresOnScreen(skew)
                    }
                    .padding(.top, topGap)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func carousel(cardWidth: CGFloat, showsMeta: Bool) -> some View {
        V2ComingUpCarousel(cards: cards, cardWidth: cardWidth, showsMeta: showsMeta, clips: wide, focused: $focused, opening: $opening)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Coming up")
                .font(.system(size: 21, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(page?.ink ?? Theme.txt)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            V2ComingUpMenu(kindsRaw: $kindsRaw, days: $days, wideStyle: hero ? $wideRaw : nil)
        }
    }

    /// The focused card's art (nil while the row is hidden): the art the
    /// card shows, so the ground's colour matches the card in the middle.
    /// The poster everywhere but the open Duo's Backdrops style.
    private var leadURL: URL? {
        guard let item = current?.item else { return nil }
        if hero, V2ComingUpWideStyle(stored: wideRaw) == .backdrops {
            return PageArtSource.url(backdrop: item.backdropUrl, poster: item.posterUrl)
        }
        return ArtPaletteExtractor.sampleURL(item.posterUrl ?? item.backdropUrl)
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
        if !opened, focused == nil, !next.isEmpty {
            opened = true
            let carried = focusLog?.log.anchor(before: bornAt)?.base as? Int
            let kept = Self.forcedOpening == nil ? carried ?? keptFocus : -1
            opening = next.contains { $0.id == kept }
                ? kept : next[min(Self.forcedOpening ?? openingIndex, next.count - 1)].id
        }
    }

    /// The window's focus log, shared by the folded and open rows.
    private var focusLog: FoldAnchorTracker? {
        foldKeep?.object("v2.home.comingUpFocus") { FoldAnchorTracker() }
    }

    /// The row opens on the third title (owner, 2026-11-07), folded and open
    /// alike, so both start on the same card with neighbours on both sides.
    private var openingIndex: Int { 2 }

    /// CI screenshots: `FUSIONHA_SCREENSHOT_COMING_UP_INDEX=<n>` opens the
    /// row on its n-th card (from 0) and keeps that shot's focus to itself.
    private static let forcedOpening: Int? = {
        #if DEBUG
        return ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_COMING_UP_INDEX"].flatMap { Int($0) }.map { max(0, $0) }
        #else
        return nil
        #endif
    }()

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
