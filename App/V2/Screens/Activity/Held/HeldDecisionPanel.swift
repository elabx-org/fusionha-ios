import SwiftUI
import FusionhaKit

/// A held download's decision (plan S8, mock `vqDecision`): who it is, then
/// 1 what's wrong (the server's sentence and the evidence side by side),
/// 2 what happens now, 3 every other choice as an override. The commit
/// button is the host's (`HeldDecisionPage`), so it can stay in view.
struct HeldDecisionPanel: View {
    let item: QueueItem
    /// The title's other downloads in the queue (the other version's badge).
    let siblings: [QueueItem]
    @Binding var choice: HeldChoice
    let canDecide: Bool
    var dense = false
    @State private var showsRelease = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            DecisionStep(number: 1, title: "What’s wrong", tone: .held, dense: dense)
            Text(HeldDecisionCopy.headline(item))
                .font(.system(size: dense ? 16 : 17, weight: .semibold))
                .foregroundStyle(Theme.txt)
                .fixedSize(horizontal: false, vertical: true)
            if let evidence = HeldDecisionCopy.evidence(item) {
                HeldEvidence(this: evidence.this, yours: evidence.yours).padding(.top, 10)
            }
            if QueueRail.held(item).nodes.count > 1 { stages.padding(.top, 10) }
            if let release = item.releaseTitle { releaseName(release).padding(.top, 8) }
            DecisionChoices(item: item, choice: $choice, canDecide: canDecide, dense: dense)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            PosterImage(url: TMDBImage.resized(item.posterUrl, to: "w185"), size: CGSize(width: 48, height: 72))
                .frame(width: 48, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: dense ? 19 : 21, weight: .bold))
                    .foregroundStyle(Theme.txt)
                    .lineLimit(2)
                Text(HeldDecisionCopy.subtitle(item))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mut)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    EditionBadge(tier: item.tier, state: .held, showsCount: false)
                    ForEach(siblings) { sibling in
                        EditionBadge(tier: sibling.tier, state: QueueLaneModel(sibling, telemetry: nil).badge,
                                     showsCount: false)
                    }
                }
                .padding(.top, 3)
            }
            Spacer(minLength: 0)
        }
    }

    /// Grabbed ✓ · Linked ✓ · Import held: v1's stage rail, as a line.
    private var stages: some View {
        let rail = QueueRail.held(item)
        let words = (rail.nodes + [rail.importNode]).map(\.label).joined(separator: " → ")
        return Text(words)
            .font(.system(size: 12))
            .foregroundStyle(Theme.mut)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The release name, folded (long, and only needed to check).
    private func releaseName(_ release: String) -> some View {
        DisclosureGroup(isExpanded: $showsRelease) {
            Text(release)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.mut)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        } label: {
            Text("Release name").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.mut)
        }
        .tint(Theme.mut)
    }
}

/// This download | your version, side by side (mock `ac-ev`).
struct HeldEvidence: View {
    let this: HeldDecisionCopy.Side
    let yours: HeldDecisionCopy.Side
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let line = 1 / max(displayScale, 1)
        HStack(alignment: .top, spacing: 0) {
            column(this)
            Rectangle().fill(Theme.txt.opacity(0.14)).frame(width: line)
            column(yours)
        }
        .fixedSize(horizontal: false, vertical: true)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.txt.opacity(0.14), lineWidth: line)
        }
    }

    private func column(_ side: HeldDecisionCopy.Side) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(side.caption.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(Theme.mut)
                .padding(.bottom, 2)
            ForEach(Array(side.lines.enumerated()), id: \.offset) { _, entry in
                Text(entry.text)
                    .font(.system(size: 12.5, weight: entry.bad ? .bold : .regular))
                    .foregroundStyle(entry.bad ? Theme.stuckText : Theme.txt)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
