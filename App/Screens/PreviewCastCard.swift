import SwiftUI
import FusionhaKit

/// One cast member: the round photo (initials until it loads), name and
/// character. v2 (a browse look) draws the stand-in in the page's quiet ink
/// rather than v1's accent gradient, and the words in the palette's inks.
struct CastCard: View {
    @Environment(\.browseLook) private var look
    @Environment(\.pagePalette) private var page
    let member: CastMember

    private var initials: String {
        let parts = member.name.split(separator: " ")
        let letters = parts.count >= 2 ? [parts[0].first, parts[1].first].compactMap { $0 } : Array(member.name.prefix(2))
        return String(letters).uppercased()
    }

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if look != nil {
                    ink.opacity(0.10)
                    Text(initials).font(.system(size: 22, weight: .bold)).foregroundStyle(muted)
                } else {
                    LinearGradient(colors: [Theme.i1, Theme.i2], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Text(initials).font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.onTint(Theme.i1))
                }
                if let url = member.profileUrl.flatMap({ TMDBImage.resized($0, to: "h632") }) {
                    DiscoverArt(url: url)
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            Text(member.name).font(.system(size: look == nil ? 14 : 13.5, weight: look == nil ? .bold : .semibold))
                .foregroundStyle(ink)
                .multilineTextAlignment(.center).lineLimit(2)
            if let character = member.character, !character.isEmpty {
                Text(character).font(.system(size: 12)).foregroundStyle(muted)
                    .multilineTextAlignment(.center).lineLimit(2)
            }
        }
        .frame(width: 96)
    }
}
