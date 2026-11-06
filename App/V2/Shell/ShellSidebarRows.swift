import SwiftUI
import FusionhaKit

/// One section of the sidebar: its icon (the tab's own image, or a symbol),
/// its name and a count. The current tab is the selected row; a needs-you
/// count is orange, every other count quiet.
struct ShellSidebarRow: View {
    var icon: String?
    var symbol: String?
    let title: String
    let on: Bool
    var count = 0
    var countNeedsYou = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                glyph
                    .foregroundStyle(on ? Theme.indigo : Theme.txt.opacity(0.7))
                    .frame(width: 22)
                Text(title)
                    .font(.body.weight(on ? .semibold : .medium))
                    .foregroundStyle(Theme.txt)
                Spacer(minLength: 0)
                if count > 0 { badge }
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 40)
            .background(on ? Theme.txt.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityValue(count > 0 ? (countNeedsYou ? "\(count) need you" : "\(count)") : "")
    }

    @ViewBuilder
    private var glyph: some View {
        if let icon {
            Image(icon).renderingMode(.template)
        } else if let symbol {
            Image(systemName: symbol).font(.body)
        }
    }

    private var badge: some View {
        Text(BadgeCount.text(count) ?? "")
            .font(.caption.weight(countNeedsYou ? .bold : .semibold).monospacedDigit())
            .foregroundStyle(countNeedsYou ? Color.white : Theme.mut)
            .padding(.horizontal, countNeedsYou ? 7 : 0)
            .frame(minWidth: 22, minHeight: 22)
            .background(countNeedsYou ? Theme.stuck : .clear, in: Capsule())
    }
}

/// The Library's kinds under it, each with its count from the loaded
/// library. Picking a kind stays in the Library's own kind control (it is
/// per window), so these are counts only.
struct ShellSidebarKinds: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let counts = Dictionary(grouping: model.library, by: \.libraryKind).mapValues(\.count)
        ForEach([LibraryKind.series, .movie, .anime], id: \.self) { kind in
            if let n = counts[kind], n > 0 {
                HStack {
                    Text(kind.plural)
                    Spacer(minLength: 0)
                    Text(n, format: .number).monospacedDigit()
                        .foregroundStyle(Theme.mut)
                }
                .font(.subheadline)
                .foregroundStyle(Theme.txt.opacity(0.85))
                .padding(.leading, 43)
                .padding(.trailing, 10)
                .frame(minHeight: 32)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// "NEEDS YOU · 2": each download waiting on you, opening its decision.
struct ShellSidebarNeeds: View {
    @Environment(AppModel.self) private var model
    let items: [QueueItem]

    var body: some View {
        Text("NEEDS YOU · \(items.count)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.mut)
            .padding(.horizontal, 10)
            .padding(.top, 16)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
        ForEach(items.prefix(6), id: \.id) { item in
            Button { V2DownloadsLinks.openQueue(model, focus: item.id) } label: {
                HStack(spacing: 10) {
                    Circle().fill(Theme.stuck).frame(width: 8, height: 8)
                    Text(label(item))
                        .font(.subheadline)
                        .foregroundStyle(Theme.txt)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(V2DownloadsLinks.reviewLabel(item))
        }
    }

    /// "VisionQuest E7 · 4K".
    private func label(_ item: QueueItem) -> String {
        let name = [item.title, item.episodeLabel].compactMap { $0 }.joined(separator: " ")
        return "\(name) · \(item.tier.badgeLetters)"
    }
}

/// The account at the sidebar's foot: avatar, name and role; opens the
/// account hub, as the column's Account item does.
struct ShellSidebarAccount: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let me = model.me {
            Button { model.avatar.showingSheet = true } label: {
                HStack(spacing: 10) {
                    AccountAvatar(me: me, size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(me.username)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.txt)
                        Text(me.roleName ?? (me.isAdmin ? "Admin" : "Member"))
                            .font(.caption)
                            .foregroundStyle(Theme.mut)
                    }
                    .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Account, \(me.username)")
        }
    }
}
