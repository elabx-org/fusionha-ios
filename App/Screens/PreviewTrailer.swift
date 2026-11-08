import SwiftUI
import FusionhaKit

/// The Preview page's trailer: the YouTube still with a play button, which
/// swaps in the player, then "Watch on YouTube". v2 (a browse look) puts
/// the play button on clear glass (a control on the art) and the link in the
/// page's muted ink; v1 keeps its scrim circle and accent link.
struct PreviewTrailer: View {
    @Environment(\.browseLook) private var look
    @Environment(\.pagePalette) private var page
    let key: String
    @State private var playing = false

    private var radius: CGFloat { look == nil ? 14 : 22 }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                if playing, let url = URL(string: "https://www.youtube-nocookie.com/embed/\(key)?autoplay=1&rel=0&playsinline=1") {
                    YouTubePlayer(url: url)
                } else {
                    Button { playing = true } label: {
                        Color.clear
                            .overlay { DiscoverArt(url: URL(string: "https://i.ytimg.com/vi/\(key)/hqdefault.jpg")) }
                            .overlay { playBadge }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(DiscoverPressStyle())
                    .accessibilityLabel("Play trailer")
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .frame(maxWidth: 640)
            .background(Theme.panel2)
            .clipShape(shape)
            .overlay(shape.strokeBorder(look == nil ? Theme.line : Color.clear))
            if let url = URL(string: "https://www.youtube.com/watch?v=\(key)") {
                Link("Watch on YouTube", destination: url)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(look == nil ? Theme.i2 : (page?.inkMuted ?? Theme.mut))
            }
        }
    }

    @ViewBuilder
    private var playBadge: some View {
        if look != nil {
            Image(systemName: "play.fill")
                .font(.system(size: 22))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .glassEffect(.regular.interactive(), in: Circle())
        } else {
            Image(systemName: "play.fill")
                .font(.system(size: 24))
                .foregroundStyle(.white)
                .frame(width: 66, height: 66)
                .background(Theme.scrim.opacity(0.62), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 2))
        }
    }
}
