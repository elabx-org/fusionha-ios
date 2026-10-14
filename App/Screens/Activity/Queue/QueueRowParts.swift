import SwiftUI
import FusionhaKit

// MARK: - Shared row bits

struct QueueMetaLine: View {
    let item: QueueItem
    var showStatus = true

    var body: some View {
        ActFlow(spacing: 0, lineSpacing: 3) {
            part {
                HStack(spacing: 3) {
                    Image(systemName: "internaldrive").font(.system(size: 9))
                    Text(ActFmt.bytes(item.size))
                }
            }
            sep
                part { Text(item.downloadClient ?? "Unknown client") }
            if let indexer = item.indexer { sep
                part { Text(indexer) } }
            if let proto = item.protocolLabel { sep
                part { Text(proto) } }
            if let trigger = item.grabTrigger, ActProvenance.meta(trigger) != nil {
                sep
                ActProvenance(trigger: trigger)
            }
            if showStatus && item.stalled {
                sep
                part { Text("no status from client — will fail soon").fontWeight(.semibold).foregroundStyle(Theme.miss) }
            } else if showStatus, let warning = item.warning {
                sep
                part { Text(warning).foregroundStyle(Theme.grab) }
            }
            if item.ageSeconds != nil { sep
                part { Text(item.queuedAgo) } }
        }
        .font(.system(size: 11))
        .foregroundStyle(Theme.mut)
    }

    private var sep: some View { Text(" · ").font(.system(size: 11)).foregroundStyle(Theme.dim) }
    private func part<C: View>(@ViewBuilder _ c: () -> C) -> some View { c().lineLimit(1) }
}

struct QueueHead: View {
    let item: QueueItem
    var chip: (String, Color)?
    /// Inside a group card the title is the group's, so the episode leads.
    var showTitle = true

    var body: some View {
        ActFlow(spacing: 6, lineSpacing: 3) {
            if showTitle || item.episodeLabel == nil {
                Text(item.title).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(1)
            }
            if let ep = item.episodeLabel, !showTitle {
                Text(ep).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(1)
            } else if let ep = item.episodeLabel {
                Text(ep).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.mut).lineLimit(1)
            }
            ActTierChip(tier: item.tier)
            if let chip {
                Text(chip.0)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(chip.1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .background(chip.1.opacity(0.12), in: Capsule())
                    .overlay(Capsule().strokeBorder(chip.1.opacity(0.35)))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}

struct ReleaseLine: View {
    let text: String?
    var body: some View {
        if let text {
            Text(text)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Theme.dim)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

struct QueueActionsView: View {
    let item: QueueItem
    let actions: QueueRowActions
    var primary: QueuePrimary?
    var stuck = false
    var trashLabel = "Remove from queue"
    var offerSearch = false

    var body: some View {
        HStack(spacing: -10) {
            if let primary {
                ActIconButton(systemImage: primary.icon, label: primary.label, tint: Theme.indigo, action: primary.run)
            }
            ActIconButton(systemImage: "trash", label: trashLabel) { actions.remove(offerSearch) }
            ActMoreMenu {
                Button("Interactive search", systemImage: "person", action: actions.interactive)
                if stuck {
                    Button("Blocklist & search", systemImage: "nosign") { actions.blocklist(true) }
                } else {
                    Button("Blocklist without removing", systemImage: "nosign") { actions.blocklist(false) }
                }
                Button("Copy release name", systemImage: "doc.on.doc", action: actions.copy)
            }
        }
        .padding(.horizontal, -6)
    }
}

/// The lg poster with a 24pt conic progress ring on its top-right corner.
struct PosterRing: View {
    let item: QueueItem
    let pct: Int
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        ActPoster(url: item.posterUrl, title: item.title, size: .lg)
            .overlay(alignment: .topTrailing) {
                ZStack {
                    Circle().fill(Theme.bg)
                    Circle().stroke(Theme.txt.opacity(0.12), lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: CGFloat(pct) / 100)
                        .stroke(Theme.grab, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(reduce ? nil : ActMotion.fill, value: pct)
                    Text("\(pct)").font(.system(size: 8, weight: .bold).monospacedDigit()).foregroundStyle(Theme.txt)
                }
                .frame(width: 24, height: 24)
                .offset(x: 8, y: -8)
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
    }
}
