import SwiftUI
import UIKit
import FusionhaKit

// Who you are, as the web's `access-shared.tsx` draws it: the role-tinted
// avatar (`UserAvatar`), the display name with the legacy "(plex:N)" mangle
// stripped (`displayName`, `Me.displayName`) and the role pill (`RoleBadge`).
// Shared by the Account page, the You tab and the avatar's hub sheet.

/// The role-tinted avatar: the Plex thumb from the avatar proxy, else the
/// initials on the role's colour.
struct AccountAvatar: View {
    @Environment(AppModel.self) private var model
    let me: Me
    var size: CGFloat = 74
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Circle().fill(fill)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(me.displayInitials)
                    .font(.system(size: max(11, size * 24 / 74), weight: .bold))
                    .foregroundStyle(me.roleTone == .other ? Theme.mut : Theme.onTint(me.roleTone.tint))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.55), radius: size * 14 / 74, y: size * 10 / 74)
        .accessibilityHidden(true)
        .task(id: me.thumb) {
            // The same-origin avatar proxy; initials when it fails.
            guard me.thumb != nil, let client = model.client,
                  let data = try? await client.avatar(userId: me.id) else { image = nil; return }
            image = UIImage(data: data)
        }
    }

    /// Person avatars keep the role's two-stop fill (the brand-gradient exception).
    private var fill: AnyShapeStyle {
        let tint = me.roleTone.tint
        switch me.roleTone {
        case .admin:
            return AnyShapeStyle(LinearGradient(colors: [Theme.avatarDeep(tint), tint],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .manager, .requestor:
            return AnyShapeStyle(LinearGradient(colors: [tint, Theme.avatarDeep(tint)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .other:
            return AnyShapeStyle(Theme.panel2)
        }
    }
}

/// The colour-coded role pill (`RoleBadge`): a dot and the role name.
struct RoleBadge: View {
    let me: Me

    var body: some View {
        let tone = me.roleTone
        HStack(spacing: 5) {
            Circle().fill(tone.tint).frame(width: 6, height: 6)
            Text(me.accountRoleName ?? "No role")
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(tone.tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(tone == .other ? Theme.panel2 : tone.tint.opacity(tone == .manager ? 0.15 : 0.16), in: Capsule())
        .accessibilityLabel("Role: \(me.accountRoleName ?? "No role")")
    }
}

extension RoleTone {
    /// Admin = the accent, Manager = cyan, Requestor = amber, anything else grey.
    var tint: Color {
        switch self {
        case .admin: return Theme.indigo
        case .manager: return Theme.cyan
        case .requestor: return Theme.miss
        case .other: return Theme.mut
        }
    }
}

/// The Account page's head (the web panel's `.head`): avatar, name, role.
struct AccountProfileHeader: View {
    let me: Me

    var body: some View {
        VStack(spacing: 8) {
            AccountAvatar(me: me, size: 74)
            Text(me.displayName)
                .font(.system(size: 18, weight: .bold))
                .tracking(-0.18)
                .foregroundStyle(Theme.txt)
                .padding(.top, 4)
                .accessibilityAddTraits(.isHeader)
            RoleBadge(me: me)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }
}
