import SwiftUI

/// A clean poster: no text over the art (design rule), and the web's dark
/// gradient placeholder while loading or when there is no art.
struct PosterImage: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.4))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            default:
                LinearGradient(colors: [Theme.panel2, Theme.card], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }
}
