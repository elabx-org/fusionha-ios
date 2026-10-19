import SwiftUI
import FusionhaKit

// MARK: - Just finished (web `JustFinishedRow.tsx`)

/// A download that reached imported or failed in the last ~20 s, lingering with
/// its real outcome: title, release line, size · client · provenance, then the
/// finished readout (or the plain fail line for a content failure), the note
/// and the draining grace bar.
struct JustFinishedRow: View {
    let entry: QueueLogic.Finished
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        let item = entry.item
        let failed = entry.failed
        let failure = FailureCopy.format(item.terminalReason, context: .import)
        HStack(alignment: .top, spacing: 12) {
            ActPoster(url: item.posterUrl, title: item.title, size: .sm)
            VStack(alignment: .leading, spacing: 5) {
                head(item, failed: failed)
                ReleaseLine(text: item.releaseTitle)
                meta(item)
                if failed && failure.isContentFailure {
                    QueueFailLine(failure: failure)
                } else {
                    FinishedReadout(item: item, failed: failed)
                    Text(note(item, failure: failure)).font(.system(size: 11.5))
                        .foregroundStyle(failed ? Theme.danger : Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                }
                graceBar(failed: failed)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            action(item, failed: failed)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .actWash(StatusTone(failed ? .danger : .done))
        .contentShape(Rectangle())
        .onTapGesture { model.open(item.mediaItemId) }
        .accessibilityAddTraits(.isButton)
    }

    private func head(_ item: QueueItem, failed: Bool) -> some View {
        let epLabel = entry.count > 1 ? entry.season.map { String(format: "S%02d", $0) } : item.episodeLabel
        return ActFlow(spacing: 6, lineSpacing: 3) {
            Text(item.title).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(1)
            if let epLabel { Text(epLabel).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.mut) }
            ActTierChip(tier: item.tier, edition: item.edition, multipleEditions: item.hasMultipleEditions == true)
            HStack(spacing: 3) {
                StatusGlyph(token: failed ? .danger : .done, size: 8)
                Text(failed ? "Failed" : "\(entry.count > 1 ? "\(entry.count) " : "")Imported")
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(failed ? Theme.danger : Theme.done)
            .padding(.horizontal, 7).padding(.vertical, 1)
            .background((failed ? Theme.danger : Theme.done).opacity(0.12), in: Capsule())
        }
    }

    /// Size (and file count for a batch) · via client · provenance.
    private func meta(_ item: QueueItem) -> some View {
        ActFlow(spacing: 6, lineSpacing: 3) {
            if item.size > 0 {
                Text(ActFmt.bytes(item.size) + (entry.count > 1 ? " · \(entry.count) files" : ""))
            }
            Text("via \(item.downloadClient ?? "decypharr")")
            if let trigger = item.grabTrigger, ActProvenance.meta(trigger) != nil {
                ActProvenance(trigger: trigger)
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(Theme.mut)
    }

    private func note(_ item: QueueItem, failure: FailureCopy.Formatted) -> String {
        let root = item.step
        if entry.failed {
            guard let stage = item.stages?.current else { return failure.detail }
            return "Failed at \(QueueRail.stageLabel(stage).lowercased()) — \(failure.detail)"
        }
        if entry.count > 1 {
            return "\(entry.count) \(entry.season != nil ? "episodes" : "files") imported\(root.map { " into \($0)" } ?? "")"
        }
        return "Imported\(root.map { " into \($0)" } ?? " into your library") · added to your library"
    }

    private func graceBar(failed: Bool) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = max(0, QueueLogic.finishedWindow - context.date.timeIntervalSince(entry.finishedAt))
            HStack(spacing: 8) {
                Text(failed ? "Failed" : "Done").font(.system(size: 11, weight: .bold))
                    .foregroundStyle(failed ? Theme.danger : Theme.done)
                Text("clears in \(Int(left.rounded()))s").font(.system(size: 11).monospacedDigit()).foregroundStyle(Theme.dim)
                GeometryReader { geo in
                    Capsule().fill((failed ? Theme.danger : Theme.done).opacity(0.5))
                        .frame(width: geo.size.width * CGFloat(left / QueueLogic.finishedWindow))
                        .animation(reduce ? nil : .linear(duration: 1), value: left)
                }
                .frame(height: 3)
            }
        }
    }

    @ViewBuilder
    private func action(_ item: QueueItem, failed: Bool) -> some View {
        if failed {
            ActIconButton(systemImage: "magnifyingglass", label: "Search for a replacement", tint: Theme.indigo) {
                Task { await ActActions.search(model.client, toaster, itemId: item.mediaItemId, editionId: item.editionId,
                                               message: "Searching again for \(item.title)") }
            }
        } else {
            ActIconButton(systemImage: "arrow.up.right.square", label: "Open in library") { model.open(item.mediaItemId) }
        }
    }
}

/// The finished row's phone readout (web `PhaseReadout` over `finishedStageModel`):
/// "Imported · N of N stages" on a full bar, or "Failed at <stage>".
struct FinishedReadout: View {
    let item: QueueItem
    let failed: Bool

    var body: some View {
        let state = item.stageState
        let total = max(1, state.runningTotal)
        let done = failed ? min(state.completed, total) : total
        let tone = failed ? Theme.danger : Theme.done
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(name).font(.system(size: 12, weight: .bold)).foregroundStyle(tone)
                Text(failed ? "stopped at \(done) of \(total)" : "\(total) of \(total) stages")
                    .font(.system(size: 11)).foregroundStyle(Theme.dim)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.txt.opacity(0.09))
                    Capsule().fill(tone).frame(width: geo.size.width * CGFloat(done) / CGFloat(total))
                }
            }
            .frame(height: 4)
        }
        .accessibilityElement(children: .combine)
    }

    private var name: String {
        guard failed else { return "Imported" }
        return item.stages?.current.map { "Failed at \(QueueRail.stageLabel($0).lowercased())" } ?? "Failed"
    }
}

/// A content failure's plain line (web `FailReasonLine`): no stepper, since the
/// release was never valid, just "✕ Download failed — dead post" and the detail.
struct QueueFailLine: View {
    let failure: FailureCopy.Formatted

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                StatusGlyph(token: .danger, size: 8)
                Text(failure.isContentFailure ? "Download failed — \(failure.title.lowercased())" : "Failed")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.danger)
            }
            (Text(failure.detail).foregroundColor(Theme.mut)
                + Text(failure.sub.map { " \($0)" } ?? "").foregroundColor(Theme.dim))
                .font(.system(size: 11.5))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
