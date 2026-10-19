import SwiftUI
import UIKit
import FusionhaKit

// MARK: - Avatar

// The avatar button (UserMenu.tsx's trigger) is the system toolbar's Account
// item now (`AccountToolbarItem`, D1).

/// The 32pt gradient-initials avatar (13/700 white), or the Plex thumb from
/// `GET /api/v1/users/{id}/avatar`, fetched with this device's credentials.
struct Avatar: View {
    @Environment(AppModel.self) private var model
    let me: Me?
    var size: CGFloat = 32
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Circle().fill(Theme.fusion)
            if let image {
                Image(uiImage: PosterWashRenderer.washed(image)).resizable().scaledToFill().clipShape(Circle())
            } else {
                Text(me?.initials ?? "")
                    .font(.system(size: size * 13 / 32, weight: .bold))
                    .foregroundStyle(Theme.onPrimary)
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(Theme.line))
        .task(id: me?.id) {
            guard let me, me.thumb != nil, let client = model.client else { image = nil; return }
            if let data = try? await client.avatarData(userId: me.id) { image = UIImage(data: data) }
        }
    }
}
