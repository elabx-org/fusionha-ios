import SwiftUI

/// A clean poster: no text over the art (design rule), a quiet placeholder while loading.
struct PosterImage: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.25))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            default:
                Rectangle().fill(.quaternary)
                    .overlay(Image(systemName: "film").foregroundStyle(.tertiary))
            }
        }
    }
}
