import SwiftUI
import FusionhaKit

/// Someone's avatar: their Plex photo (`GET /users/{id}/avatar`) when they
/// have one, else their initials on a disc tinted by their id (the web's
/// `hueForId`), muted to hsl(h 40% 46%) → hsl(h+30 45% 38%) so a person
/// never reads as a status hue, with a ring in the ground colour.
/// Monochrome keeps it grey.
struct PersonAvatar: View {
    @Environment(AppModel.self) private var model
    let userId: Int
    let name: String
    let hasThumb: Bool
    var size: CGFloat = 34
    @State private var image: UIImage?

    private var disc: AnyShapeStyle {
        if Theme.isMono { return AnyShapeStyle(Theme.panel2) }
        let h = PersonInitials.hue(userId) / 360
        let top = Color(hue: h, saturation: 0.571, brightness: 0.644)
        let bottom = Color(hue: ((PersonInitials.hue(userId) + 30) / 360).truncatingRemainder(dividingBy: 1),
                           saturation: 0.621, brightness: 0.551)
        return AnyShapeStyle(LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    var body: some View {
        ZStack {
            Circle().fill(disc)
            if let image {
                Image(uiImage: PosterWashRenderer.washed(image)).resizable().scaledToFill().clipShape(Circle())
            } else {
                Text(PersonInitials.of(name))
                    .font(.system(size: max(11, size * 13 / 32), weight: .bold))
                    .foregroundStyle(Theme.isMono ? Theme.txt : .white)
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(Theme.bg, lineWidth: 2))
        .accessibilityHidden(true)
        .task(id: userId) {
            guard hasThumb, let client = model.client else { image = nil; return }
            if let data = try? await client.avatarData(userId: userId) { image = UIImage(data: data) }
        }
    }
}
