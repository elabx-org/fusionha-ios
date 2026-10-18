import SwiftUI
import FusionhaKit

// The Requests card scale (fusionha 0.4.214): the inbox row's poster, tier
// chips and requester avatar at the web's sizes.

/// The inbox row's poster: 44 pt wide, 2:3.
struct RequestRowPoster: View {
    let url: String?
    let title: String

    var body: some View {
        PosterImage(url: TMDBImage.resized(url, to: "w154"))
            .overlay {
                if url == nil {
                    Text(String(title.prefix(1)).uppercased())
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Theme.mut)
                }
            }
            .frame(width: 44, height: 66)
            .shelfPoster(radius: 7)
            .accessibilityHidden(true)
    }
}

/// A tier chip at the row scale: 10.5 pt, 19 pt tall, HD purple / 4K cyan.
struct RequestRowTierChip: View {
    let tier: QualityTier

    var body: some View {
        Text(tier.chipLabel)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(tier.color)
            .padding(.horizontal, 6)
            .frame(height: 19)
            .background(EditionChipBackground(color: tier.color))
            .lineLimit(1)
            .fixedSize()
    }
}

/// A requester's initials avatar (22 pt on the row, 24 pt on the deck's pill;
/// initials at the 11 pt floor, a step over the web's 9 px).
struct RequestAvatar: View {
    let name: String
    var size: CGFloat = 22
    var fontSize: CGFloat = 11

    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: fontSize, weight: .bold))
            .foregroundStyle(Theme.onPrimary)
            .frame(width: size, height: size)
            .background(Theme.fusion, in: Circle())
            .accessibilityHidden(true)
    }
}
