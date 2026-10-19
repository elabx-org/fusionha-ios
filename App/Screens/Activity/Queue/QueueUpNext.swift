import SwiftUI
import FusionhaKit

// MARK: - Up next (web `OnDeckCard.tsx`, `CompactUpNextRow.tsx`)

/// The muted grey wash every Up next slot shares.
private var upNextWash: StatusTone { StatusTone(color: Theme.dim) }

/// The #1 slot: a full card with a ghosted rail. A slot decypharr has already
/// begun shows its phase chip and live phase note; otherwise a muted ON DECK
/// chip and "Waiting to start".
struct OnDeckCard: View {
    let item: QueueItem
    let actions: QueueRowActions

    var body: some View {
        let phaseMode = item.isPhaseMode
        let meta = item.phaseMeta
        HStack(alignment: .top, spacing: 12) {
            Text("1").font(.system(size: 13, weight: .heavy, design: .monospaced)).foregroundStyle(Theme.dim).frame(width: 14)
            ActPoster(url: item.posterUrl, title: item.title, size: .sm)
            VStack(alignment: .leading, spacing: 5) {
                QueueHead(item: item, chip: phaseMode ? (chipLabel, meta.tone) : ("ON DECK", Theme.mut))
                ReleaseLine(text: item.releaseTitle)
                PhaseReadout(item: item, ghost: true)
                HStack {
                    UpNextWaitLine(item: item, lead: phaseMode ? QueueLogic.noteLine(item) : "Waiting to start")
                    Spacer(minLength: 0)
                    ActIconButton(systemImage: "trash", label: "Remove \(item.title) from queue") { actions.remove(false) }
                        .padding(.trailing, -8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .actWash(upNextWash)
    }

    /// The phase name, with the linking count when the wire has one.
    private var chipLabel: String {
        guard let linking = item.linkingCount else { return item.phaseMeta.label }
        return "\(item.phaseMeta.label) (\(linking.done)/\(linking.total))"
    }
}

/// "Waiting to start · 4.2 GB · client · indexer": the quiet caption under a ghost rail.
struct UpNextWaitLine: View {
    let item: QueueItem
    let lead: String

    var body: some View {
        let rest = ([ActFmt.bytes(item.size), item.downloadClient ?? "Unknown client"] + [item.indexer].compactMap { $0 })
            .joined(separator: " · ")
        (Text(lead).fontWeight(.semibold).foregroundColor(Theme.mut) + Text(" · " + rest).foregroundColor(Theme.dim))
            .font(.system(size: 11))
            .lineLimit(2)
    }
}

/// A #2..N slot: one compact line; the whole line opens it in place to the
/// release, the ghost rail and its position. The tab keeps one open at a time.
struct CompactUpNextRow: View {
    let item: QueueItem
    let position: Int
    let actions: QueueRowActions
    let expanded: Bool
    let toggle: () -> Void
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("\(position)").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Theme.dim).frame(width: 18)
                ActPoster(url: item.posterUrl, title: item.title, size: .sm)
                VStack(alignment: .leading, spacing: 3) {
                    QueueHead(item: item, chip: ("QUEUED", Theme.mut))
                    Text([ActFmt.bytes(item.size), item.indexer].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 11)).foregroundStyle(Theme.mut)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.dim)
                    .rotationEffect(.degrees(expanded ? 90 : 0)).frame(width: 30, height: 30)
                    .accessibilityHidden(true)
                ActIconButton(systemImage: "trash", label: "Remove \(item.title) from queue") { actions.remove(false) }
                    .padding(.horizontal, -8)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if reduce { toggle() } else { withAnimation(.easeOut(duration: 0.2)) { toggle() } }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(expanded ? "Hides the release" : "Shows the release")
            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    ReleaseLine(text: item.releaseTitle ?? item.title)
                    PhaseReadout(item: item, ghost: true)
                    UpNextWaitLine(item: item, lead: "Position \(position) in line")
                }
                .padding(.leading, 28)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .actWash(upNextWash)
    }
}
