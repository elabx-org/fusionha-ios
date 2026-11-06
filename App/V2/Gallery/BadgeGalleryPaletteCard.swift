import SwiftUI
import FusionhaKit

/// One palette's page of the Badge gallery, drawn in that palette's tokens
/// (ground, text and badge ink) rather than the active palette's.
struct BadgeGalleryPaletteCard: View {
    let palette: AppPalette
    let sizeLabel: String

    private var tokens: PaletteTokens { palette.tokens }
    private var txt: Color { Color(hex: tokens.txt) }
    private var mut: Color { Color(hex: tokens.mut) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            group("Badges") {
                ForEach(BadgeGallerySamples.singles) { s in
                    BadgeGalleryRow(label: s.label, labelColor: mut) {
                        HStack(spacing: 10) {
                            EditionBadge(tier: .hd, state: s.state)
                            EditionBadge(tier: .uhd, state: s.state)
                        }
                    }
                }
            }
            group("HD and 4K pairs") {
                ForEach(BadgeGallerySamples.pairs) { p in
                    BadgeGalleryRow(label: p.label, labelColor: mut) {
                        EditionTicketPair(hd: p.hd, uhd: p.uhd)
                    }
                }
            }
            group("Rails") { rails }
            group("On artwork") { onArt }
        }
        .padding(16)
        .background(Color(hex: tokens.bg), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(Color(hex: tokens.line).opacity(tokens.lineOpacity), lineWidth: 1))
        .badgeInk(.page(tokens))
        .environment(\.colorScheme, tokens.isLight ? .light : .dark)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(palette.name).font(.title3.weight(.bold)).foregroundStyle(txt)
            Spacer(minLength: 8)
            Text(sizeLabel).font(.footnote.weight(.semibold)).foregroundStyle(mut)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.caption.weight(.heavy))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(Color(hex: tokens.dim))
            content()
        }
    }

    @ViewBuilder
    private var rails: some View {
        ForEach(BadgeGallerySamples.seasons) { season in
            let rest = OneInkRail.rest(for: season.state)
            VStack(alignment: .leading, spacing: 6) {
                Text(season.label).font(.footnote).foregroundStyle(mut)
                seasonLine(season) {
                    RailBarV2(have: season.have, aired: season.aired, total: season.total, rest: rest)
                }
                seasonLine(season) {
                    EpisodeTicks(have: season.have, aired: season.aired, total: season.total, rest: rest)
                }
            }
        }
        BadgeGalleryRow(label: "Download 62%", labelColor: mut) {
            RailBarV2(progress: 0.62).frame(maxWidth: 160)
        }
        StorageCapsule(segments: BadgeGallerySamples.storage, capacity: BadgeGallerySamples.storageCapacity)
    }

    private func seasonLine<Bar: View>(_ season: BadgeGallerySamples.Season, @ViewBuilder bar: () -> Bar) -> some View {
        HStack(spacing: 8) {
            EditionBadge(tier: .hd, state: season.state, showsCount: false)
            bar()
            Text(OneInkRail.countLine(have: season.have, aired: season.aired))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(mut)
                .fixedSize()
        }
    }

    /// Hero cards: white ink on a dark art plate in every palette.
    private var onArt: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(BadgeGallerySamples.pairs.prefix(6)) { p in
                EditionTicketPair(hd: p.hd, uhd: p.uhd)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(hex: 0x3A2A55), Color(hex: 0x0E2A36)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .badgeInk(.onArt(tokens))
    }
}

/// A label and its sample, side by side; stacked at accessibility sizes.
struct BadgeGalleryRow<Sample: View>: View {
    let label: String
    let labelColor: Color
    @ViewBuilder let sample: () -> Sample
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: 12))
        layout {
            Text(label).font(.footnote).foregroundStyle(labelColor)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            sample()
        }
    }
}
