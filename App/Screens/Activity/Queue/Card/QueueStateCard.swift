import SwiftUI
import FusionhaKit

/// A queue card in any state but held, on the web's v4 frame (CardShell +
/// card-bodies): poster and title (or, nested in a group, the episode with
/// the icon actions), the meta line, release chips, source line, then the
/// state's body (stage rail and its reason) and the bottom row (the state's
/// readout or primary button beside the icon actions).
struct QueueStateCard: View {
    let item: QueueItem
    let telemetry: QueueTelemetry?
    let actions: QueueRowActions
    var nested = false
    /// A lane of a 4K + HD pair: the version leads, not the shared episode.
    var pairLane = false
    var soonest = false
    @Environment(AppModel.self) private var model

    private var mode: QueueCardMode { QueueCardMode(item) }

    var body: some View {
        let mode = self.mode
        VStack(alignment: .leading, spacing: 12) {
            if nested { nestedHead(mode) } else { QueueCardHead(item: item) }
            QueueCardMeta(item: item, showTier: !nested, fullDownload: mode == .bytes)
            QueueFactChips(item: item)
            QueueSourceLine(item: item)
            QueueStateBody(item: item, mode: mode, telemetry: telemetry)
            if !nested || mode != .other {
                HStack(spacing: 10) {
                    QueueStateReadout(item: item, mode: mode, telemetry: telemetry, search: actions.search)
                    Spacer(minLength: 0)
                    if !nested { QueueCardActions(item: item, actions: actions, broken: mode.isBroken) }
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, nested ? 14 : 18)
        .actWash(QueueLogic.wash(item), radius: nested ? 12 : 16, base: nested ? Theme.panel.opacity(0.55) : Theme.card,
                 border: nested ? .clear : Theme.line)
        .accessibilityElement(children: .contain)
    }

    private func nestedHead(_ mode: QueueCardMode) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(pairLane ? QueueCardText.versionLabel(item) : (QueueCardText.subtitle(item) ?? item.releaseTitle ?? item.title))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.txt)
                .lineLimit(2)
            Spacer(minLength: 4)
            QueueCardActions(item: item, actions: actions, broken: mode.isBroken)
                .padding(.trailing, -8)
        }
    }
}

/// Poster, title and episode (or year) of a single card.
struct QueueCardHead: View {
    let item: QueueItem
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ActPoster(url: item.posterUrl, title: item.title, size: .md)
                .onTapGesture { model.open(item.mediaItemId) }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(2)
                    .onTapGesture { model.open(item.mediaItemId) }
                    .accessibilityAddTraits(.isButton)
                if let sub = QueueCardText.subtitle(item) {
                    Text(sub).font(.system(size: 15)).foregroundStyle(Theme.mut).lineLimit(2)
                }
            }
            .padding(.top, 6)
            Spacer(minLength: 0)
        }
    }
}

/// The state's body: the stage rail, then its reason (web `card-bodies`).
struct QueueStateBody: View {
    let item: QueueItem
    let mode: QueueCardMode
    let telemetry: QueueTelemetry?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            QueueStageRailView(model: rail)
            switch mode {
            case .bytes:
                ActProgressBar(fraction: Double(item.pct) / 100, height: 5, shimmer: !item.stalled)
                reason(item.stalled ? "Stalled" : nil,
                       item.stalled ? "\(client) has reported no progress for a while."
                                    : "A real transfer: \(client) is fetching the whole file, so the percent and speed are true.")
            case .waiting:
                reason("Waiting for the client", item.warning)
            case .other:
                reason(nil, item.stalled ? "Stalled · \(client) has reported no progress for a while."
                                         : "\(client) reports it as \(item.status.lowercased()).")
            case .importing:
                if item.phase == "importing", let dest = item.step {
                    (Text("Moving into ") + Text(dest).font(.system(size: 14, design: .monospaced)))
                        .font(.system(size: 15)).foregroundStyle(Theme.mut)
                } else {
                    reason(nil, "Writing the library entry…")
                }
                ActIndeterminateBar(color: Theme.done, height: 3)
            case .retrying:
                let at = item.stages?.current.map { " · at \(QueueRail.stageLabel($0).lowercased())" } ?? ""
                reason("Retrying" + at, failure)
            case .failed:
                let at = item.stages?.current.map { "Failed at \(QueueRail.stageLabel($0).lowercased())" } ?? "Failed"
                reason(at, failure)
            case .stuck:
                reason("No release left to try", item.nextStep ?? "every candidate was tried or blocklisted")
            case .phase, .held:
                EmptyView()
            }
            if [.bytes, .waiting, .other].contains(mode), let next = item.nextStep {
                Text(next).font(.system(size: 14)).foregroundStyle(Theme.mut)
            }
            if item.hasPackDecisions {
                QueuePackDecisionsView(item: item)
            } else if let ranges = item.packRanges {
                QueuePackLine(item: item, ranges: ranges)
            }
            if item.hasPackDecisions || item.packRanges != nil {
                QueuePackEpisodesList(downloadId: item.id, fileCount: item.fileCount)
            }
        }
    }

    private var client: String { item.downloadClient ?? "The download client" }

    private var failure: String? { item.terminalReason ?? item.step ?? item.warning }

    private var rail: QueueRailModel {
        switch mode {
        case .bytes: return QueueRail.model(item, .bytes(pct: item.pct))
        case .waiting: return QueueRail.model(item, .waiting)
        case .other: return QueueRail.model(item, .other)
        case .phase: return QueueRail.model(item, .phase)
        case .retrying: return QueueRail.model(item, .retrying)
        case .failed: return QueueRail.model(item, .failed)
        case .stuck: return QueueRail.model(item, .stuck)
        case .importing: return QueueRail.importing(item)
        case .held: return QueueRail.held(item)
        }
    }

    private func reason(_ lead: String?, _ detail: String?) -> some View {
        let head = lead.map { Text($0).fontWeight(.semibold).foregroundColor(Theme.txt) } ?? Text("")
        let sep = lead != nil && detail != nil ? Text(" · ").foregroundColor(Theme.dim) : Text("")
        return (head + sep + Text(detail ?? "").foregroundColor(Theme.mut))
            .font(.system(size: 15))
            .fixedSize(horizontal: false, vertical: true)
    }
}
