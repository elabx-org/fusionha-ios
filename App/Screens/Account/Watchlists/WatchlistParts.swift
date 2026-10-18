import SwiftUI
import FusionhaKit

/// A card's state pill: a dot and a word in the state's colour.
struct WatchlistPill: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.14), in: Capsule())
        .fixedSize()
    }
}

/// The card head: icon tile, title, the line under it, the pill.
struct WatchlistCardHead: View {
    let icon: String
    let tint: Color
    let title: String
    let sub: String
    let pill: String
    let pillColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.isMono ? Theme.bg : .white)
                .frame(width: 30, height: 30)
                .background(Theme.isMono ? Theme.mut : tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt)
                Text(sub).font(.footnote).foregroundStyle(Theme.mut)
            }
            Spacer(minLength: 8)
            WatchlistPill(text: pill, color: pillColor)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Three numbers in a row: "Requested from Plex · Last checked · Next check".
struct WatchlistStatsRow: View {
    let items: [(value: String, label: String)]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.value)
                        .font(.system(size: 15, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.txt)
                        .contentTransition(.numericText())
                    Text(item.label).font(.caption).foregroundStyle(Theme.mut)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A warning line in the state's colour (web `Attention`).
struct WatchlistAttention: View {
    let lead: String
    let rest: String
    var color: Color = Theme.stuck

    var body: some View {
        Label {
            (Text(lead).bold() + Text(" " + rest)).font(.footnote).foregroundStyle(Theme.txt)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(color)
        }
    }
}

/// An info line (web `.info`): an icon and a sentence with a bold lead.
struct WatchlistInfo: View {
    var icon = "info.circle"
    let lead: String
    let rest: String

    var body: some View {
        Label {
            (Text(lead).bold() + Text(" " + rest)).font(.footnote).foregroundStyle(Theme.mut)
        } icon: {
            Image(systemName: icon).foregroundStyle(Theme.dim)
        }
    }
}

/// A Sync now button with its cooldown: spinner while checking, "Sync now"
/// otherwise, disabled until `retryAt` passes (ticks every second).
struct WatchlistSyncRow: View {
    let title: String
    let sub: String
    let retryAt: String?
    let syncing: Bool
    let waitText: (Int) -> String
    let action: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = WatchlistTime.secondsLeft(retryAt, now: context.date)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(Theme.txt)
                    Text(left > 0 && !syncing ? waitText(left) : sub).font(.caption).foregroundStyle(Theme.mut)
                }
                Spacer(minLength: 8)
                Button(action: action) {
                    if syncing {
                        HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Checking…") }
                    } else {
                        Label("Sync now", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(syncing || left > 0)
            }
        }
    }
}

extension LbTone {
    var color: Color {
        switch self {
        case .done: return Theme.done
        case .miss: return Theme.miss
        case .stuck: return Theme.stuck
        case .grab: return Theme.grab
        case .dim: return Theme.dim
        }
    }
}
