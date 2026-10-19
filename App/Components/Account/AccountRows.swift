import SwiftUI
import FusionhaKit

/// The account sheet's shared look: rows on solid cells over the sheet glass.
enum AccountStyle {
    static var cell: Color { Theme.panel.opacity(0.86) }
}

/// A Settings-style row: a tinted icon tile, the title, an optional value,
/// and a chevron or ↗ for rows that leave the sheet.
struct AccountRow: View {
    let icon: String
    let tint: Color
    let title: String
    var value: String? = nil
    var chevron = false
    var external = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.isMono ? Theme.bg : Theme.onTint(tint))
                .frame(width: 28, height: 28)
                .background(Theme.isMono ? Theme.mut : tint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text(title).foregroundStyle(Theme.txt)
            Spacer(minLength: 8)
            if let value { Text(value).foregroundStyle(Theme.mut) }
            if chevron {
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.dim)
            } else if external {
                Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.dim)
            }
        }
        .contentShape(Rectangle())
    }
}

/// The sheet's top (the web Account panel's `.head`): the role-tinted
/// avatar, the display name, the role badge and server, and a health line.
struct AccountHeader: View {
    let me: Me?
    let server: URL?
    let queued: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                if let me {
                    AccountAvatar(me: me, size: 52)
                } else {
                    Avatar(me: nil, size: 52)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(me?.displayName ?? "Signed in")
                        .font(.system(size: 19, weight: .bold)).foregroundStyle(Theme.txt)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        if let me { RoleBadge(me: me) }
                        if let host = server?.host {
                            Text(host).font(.subheadline).foregroundStyle(Theme.mut).lineLimit(1)
                        }
                    }
                }
            }
            HStack(spacing: 8) {
                Circle().fill(me != nil ? Theme.done : Theme.miss).frame(width: 7, height: 7)
                Text(me != nil ? "Connected\(queued > 0 ? " · \(queued) in queue" : "")" : "Connecting…")
                    .font(.footnote).foregroundStyle(Theme.mut)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
