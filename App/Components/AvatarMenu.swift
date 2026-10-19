import SwiftUI
import UIKit
import FusionhaKit

// MARK: - User menu

/// The avatar button (UserMenu.tsx's trigger). The amber dot shows when
/// something needs attention. It only sets `AppModel.avatar.showingSheet`: the
/// account sheet and what it opens (Settings, Account, Widgets) are presented
/// once from the shell (`AvatarPresentations`), so the button can move into a
/// system toolbar or its overflow without losing them.
struct AvatarMenu: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button { model.avatar.showingSheet = true } label: { label }
            .buttonStyle(.plain)
            .accessibilityLabel(model.attentionCount > 0 ? "Account, \(model.attentionCount) need attention" : "Account")
    }

    private var label: some View {
        Avatar(me: model.me, size: 32)
            .overlay(alignment: .topTrailing) {
                if model.attentionCount > 0 && !model.requestScoped {
                    Circle()
                        .fill(Theme.miss)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().strokeBorder(Theme.bg, lineWidth: 2).padding(-2))
                        .offset(x: 1, y: -1)
                }
            }
            .frame(width: 32, height: 32)
            .padding(6)
            .contentShape(Circle())
            .padding(-6)
    }
}

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
