import SwiftUI
import FusionhaKit

extension UsersRoster.Accent {
    var color: Color {
        switch self {
        case .premiere: return Theme.premiere
        case .miss: return Theme.miss
        case .grab: return Theme.grab
        case .mut: return Theme.mut
        case .unmonitored: return Theme.unmonitored
        case .danger: return Theme.danger
        case .plex: return Theme.plexGold
        }
    }
}

/// The Users pulse (web `UsersPulse`): one tinted count chip per bucket that
/// filters the list (tap again to clear), then the roster bar (admins ·
/// members · disabled) with its legend.
struct UsersPulseView: View {
    let users: [UserAccount]
    @Binding var selection: UsersRoster.PulseKey?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(UsersRoster.PulseKey.allCases, id: \.self) { chip($0) }
                }
            }
            roster
        }
    }

    private func chip(_ key: UsersRoster.PulseKey) -> some View {
        let color = UsersRoster.accent(key).color
        let on = selection == key
        let n = UsersRoster.count(key, in: users)
        return Button {
            withAnimation(reduceMotion ? nil : .snappy) { selection = on ? nil : key }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text("\(n)").font(.system(size: 15, weight: .bold).monospacedDigit()).foregroundStyle(Theme.txt)
                Text(key.label).font(.system(size: 12, weight: .semibold)).foregroundStyle(on ? Theme.txt : Theme.mut)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(color.opacity(on ? 0.28 : 0.12), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(n) \(key.label)")
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityHint(on ? "Shows everyone" : "Shows only these users")
    }

    private var segments: [(label: String, color: Color, n: Int)] {
        let admins = users.filter { $0.isAdmin && UsersRoster.isActive($0) }.count
        let members = users.filter { !$0.isAdmin && UsersRoster.isActive($0) }.count
        let disabled = users.filter { !UsersRoster.isActive($0) }.count
        return [("Admins", Theme.premiere, admins), ("Members", Theme.miss, members), ("Disabled", Theme.unmonitored, disabled)]
    }

    private var roster: some View {
        let segs = segments
        let total = max(1, segs.reduce(0) { $0 + $1.n })
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Roster").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
                Text("\(users.count) accounts").font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(segs.filter { $0.n > 0 }, id: \.label) { seg in
                        Rectangle().fill(seg.color)
                            .frame(width: max(0, (geo.size.width - 4) * CGFloat(seg.n) / CGFloat(total)))
                    }
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())
            .accessibilityHidden(true)
            HStack(spacing: 14) {
                ForEach(segs, id: \.label) { seg in
                    HStack(spacing: 5) {
                        Circle().fill(seg.color).frame(width: 7, height: 7)
                        Text("\(seg.n)").fontWeight(.bold).foregroundStyle(Theme.txt)
                        Text(seg.label).foregroundStyle(Theme.mut)
                    }
                    .font(.system(size: 12))
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

/// A group's header (web `GroupHead`): chevron, accent dot, name, count; tap
/// to collapse.
struct UsersGroupHeader: View {
    let group: UsersRoster.Group
    let collapsed: Bool
    let toggle: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .snappy) { toggle() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .rotationEffect(.degrees(collapsed ? -90 : 0))
                    .foregroundStyle(Theme.dim)
                Circle().fill(group.accent.color).frame(width: 7, height: 7)
                Text(group.label).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
                Text("\(group.users.count)")
                    .font(.system(size: 11, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.mut)
                    .padding(.horizontal, 7).padding(.vertical, 1)
                    .background(Theme.panel2, in: Capsule())
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .textCase(nil)
        .accessibilityValue(collapsed ? "Collapsed" : "Expanded")
    }
}
