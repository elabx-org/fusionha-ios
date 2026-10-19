import SwiftUI
import FusionhaKit

/// One person in Settings › Access › Users: avatar, name and status tags,
/// "Admin · 2 sessions · 23 auto-requested", the UHD·4K chip with its
/// qualifier, then one pill per automatic source.
struct UsersListRow: View {
    let user: UserAccount
    let plex: PlexWatchlistSummaryRow?
    let letterboxd: LetterboxdSummaryRow?
    let uhd: UserTierAccess?

    private var disabled: Bool { !UsersRoster.isActive(user) }

    var body: some View {
        let sessions = user.activeSessionCount ?? 0
        let meta = [user.isAdmin ? "Admin" : (user.roleName ?? "No role"),
                    sessions > 0 ? "\(sessions) \(sessions == 1 ? "session" : "sessions")" : nil,
                    UserSourceChips.requestedLine(plex: plex, letterboxd: letterboxd)]
        HStack(alignment: .top, spacing: 12) {
            PersonAvatar(userId: user.id, name: user.displayName, hasThumb: user.thumb != nil)
                .opacity(disabled ? 0.45 : 1)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(user.displayName).font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(disabled ? Theme.dim : Theme.txt)
                        .lineLimit(1)
                    if UsersRoster.fromPlex(user) { UserStatusTag(word: "Plex", color: Theme.plexGold) }
                    if disabled { UserStatusTag(word: "Disabled", color: Theme.danger) }
                }
                Text(meta.compactMap { $0 }.joined(separator: " · ")).font(.system(size: 13)).foregroundStyle(Theme.mut)
                if let uhd {
                    HStack(spacing: 6) {
                        UsersUhdChip(access: uhd)
                        if let why = UsersUHD.qualifier(uhd) {
                            Text(why).font(.system(size: 11)).foregroundStyle(uhd.stale || uhd.frozen ? Theme.stuck : Theme.dim)
                                .lineLimit(1)
                        }
                    }
                }
                UserSourceChips(plex: plex, letterboxd: letterboxd)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.dim)
                .frame(maxHeight: .infinity)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// A status word on a tinted fill (web `StatusBadge`): never a border.
struct UserStatusTag: View {
    let word: String
    let color: Color

    var body: some View {
        Text(word)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Theme.isMono ? Theme.txt : color)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(color.opacity(0.16), in: Capsule())
            .fixedSize()
    }
}
