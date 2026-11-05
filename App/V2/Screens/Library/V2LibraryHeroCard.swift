import SwiftUI
import FusionhaKit

/// One Library hero card (mock kit `heroCard`): the title's textless art
/// over the top of a 30pt card that fades into a tint taken from that art,
/// then, centred at the foot, the title (in text until the server sends a
/// logo), the network mark and "year · kind", the HD and 4K ticket and the
/// next thing that matters. Content, not glass; always on dark.
struct V2LibraryHeroCard: View {
    let item: MediaItem
    let width: CGFloat
    let height: CGFloat
    /// Off while the card only peeks beside the centred one (mock `.hcard.peek`).
    var showsFooter = true
    /// Why the card is here ("S2 E5 · tonight"); takes the "year · kind" line.
    var note: String? = nil
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    /// The art's lead colour; lifted in `body`, so a palette switch re-lifts it.
    @State private var lead: HSLColor?
    /// The network mark, from the title's detail (`V2StudioMarkCache`).
    @State private var studio: Studio?

    private var art: URL? { TMDBImage.resized(item.backdropUrl ?? item.posterUrl, to: "w780") }
    private var narrow: Bool { width < 200 }

    /// The foot's tint: the lead colour lifted for a dark card (grey on the
    /// hue-less palettes).
    private var foot: Color {
        guard let lead else { return Color(white: 0.12) }
        let lifted = PaletteMath.lift(lead, dark: true, mono: PagePalette.dropsHue(Theme.palette))
        return Color(hsl: PaletteMath.tint(lifted, dark: true))
    }

    var body: some View {
        Button { model.open(item.id) } label: {
            ZStack(alignment: .bottom) {
                foot
                PosterImage(url: art, size: CGSize(width: width, height: height * 0.84))
                    .frame(width: width, height: height * 0.84)
                    .clipped()
                    .frame(maxHeight: .infinity, alignment: .top)
                LinearGradient(stops: [.init(color: foot.opacity(0), location: 0),
                                       .init(color: foot, location: 0.52)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: height * 0.58)
                footer
                    .opacity(showsFooter ? 1 : 0)
                    .animation(motion ? .easeOut(duration: 0.2) : nil, value: showsFooter)
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(.white.opacity(0.08)))
            .shadow(color: .black.opacity(0.3), radius: 20, y: 18)
            .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
        .environment(\.colorScheme, .dark)
        .badgeInk(.onArt)
        .task(id: art) { await loadLead() }
        // Only the card showing its footer asks; a peeking one waits until centred.
        .task(id: showsFooter ? item.id : nil) { await loadMark() }
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(spacing: narrow ? 8 : 9) {
            Text(item.title)
                .font(.system(size: width < 230 ? 20 : 24, weight: .bold))
                .tracking(-0.3)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .shadow(color: .black.opacity(0.55), radius: 10, y: 2)
            V2NetworkMarkLine(studio: studio) {
                Text(note ?? meta)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            let badges = V2EditionBadges(item) { model.queueSlots.slot(for: $0.id).progress }
            EditionTicketPair(hd: badges.hd, uhd: badges.uhd)
            // With a reason line, only what is moving or needs the owner.
            if let next = V2HeroNextLine(item), note == nil || next.needsYou || item.cardStatus == .downloading {
                Text(next.text)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(next.needsYou ? Theme.stuck : .white.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, narrow ? 10 : 18)
        .padding(.bottom, narrow ? 16 : 18)
    }

    private var meta: String {
        let kind = item.isAnime == true ? "Anime" : item.kind == .movie ? "Movie" : "Series"
        return [item.year.map(String.init), kind].compactMap { $0 }.joined(separator: " · ")
    }

    private func loadMark() async {
        guard showsFooter, let client = model.client else { return }
        if let known = V2StudioMarkCache.shared.cached(item.id, server: client.baseURL) {
            studio = known
            return
        }
        let mark = await V2StudioMarkCache.shared.mark(for: item.id, client: client)
        guard !Task.isCancelled else { return }
        studio = mark
    }

    /// The art's lead colour, cached per art (`ArtPaletteExtractor`).
    private func loadLead() async {
        guard let sample = PageArtSource.url(backdrop: item.backdropUrl, poster: item.posterUrl) else { return }
        let colors: [HSLColor]?
        if let hit = ArtPaletteExtractor.shared.cached(sample) {
            colors = hit
        } else {
            colors = await ArtPaletteExtractor.shared.colors(for: sample)
        }
        guard let first = colors?.first, !Task.isCancelled else { return }
        lead = first
    }
}

/// The hero's last line: what happens next for the title.
struct V2HeroNextLine {
    let text: String
    let needsYou: Bool

    init?(_ item: MediaItem) {
        if item.hasAttention == true {
            text = "Needs you"
            needsYou = true
        } else if item.cardStatus == .downloading {
            text = "Downloading"
            needsYou = false
        } else if item.cardStatus == .missing, item.monitored ?? true {
            text = item.kind == .movie ? "Missing" : "Episodes missing"
            needsYou = false
        } else if let next = Format.day(item.nextRelease) ?? Format.timestamp(item.nextRelease), next > Date() {
            text = "Next \(next.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))"
            needsYou = false
        } else {
            return nil
        }
    }
}
