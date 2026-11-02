import SwiftUI
import FusionhaKit

/// The provider tile of a followed source or an import list (web
/// `ProviderTile`, fusionha 0.4.237): Letterboxd's three circles, Plex's list
/// mark, MDBList's M and Trakt's T. MDBList and Trakt have no official mark in
/// the app, so the tile carries the web's letter in the site's colour.
/// `small` is the round chip of the Works with row and the Recognised line.
struct ProviderTile: View {
    let provider: SourceProvider
    var size: CGFloat = 30
    var small = false

    private var radius: CGFloat { small ? size / 2 : size * 0.28 }

    var body: some View {
        glyph
            .frame(width: size, height: size)
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.line))
            .accessibilityHidden(true)
    }

    @ViewBuilder private var glyph: some View {
        switch provider {
        case .plex:
            WatchlistMarkGlyph(mark: .list, size: size * 0.55).foregroundStyle(WatchlistMark.list.ink)
        case .letterboxd:
            WatchlistMarkGlyph(mark: .letterboxd, size: size * 0.58).foregroundStyle(WatchlistMark.letterboxd.ink)
        case .mdblist, .trakt:
            Text(provider == .mdblist ? "M" : "T")
                .font(.system(size: size * 0.45, weight: .heavy))
                .foregroundStyle(Self.brand(provider))
        }
    }

    /// The web's `color-mix(--pc 16%, --panel2)`: a quiet wash of the site's colour.
    private var fill: some ShapeStyle {
        switch provider {
        case .mdblist, .trakt: return AnyShapeStyle(Theme.panel2.mix(with: Self.brand(provider), by: 0.16))
        default: return AnyShapeStyle(Theme.panel2)
        }
    }

    /// `--provider-mdblist` / `--provider-trakt`, grey under Monochrome.
    static func brand(_ provider: SourceProvider) -> Color {
        switch provider {
        case .mdblist: return Theme.brand(0x4F8DF5)
        case .trakt: return Theme.brand(0xED1C24)
        case .letterboxd: return Theme.brand(0x00C030)
        case .plex: return Theme.plexGold
        }
    }
}

/// "MDBList · public list": the small tile and the site's word (the Works
/// with row, the Recognised line).
struct ProviderChip: View {
    let provider: SourceProvider
    var text: String?

    var body: some View {
        HStack(spacing: 6) {
            ProviderTile(provider: provider, size: 20, small: true)
            Text(text ?? provider.word).font(.caption.weight(.semibold)).foregroundStyle(Theme.txt)
        }
        .accessibilityElement(children: .combine)
    }
}
