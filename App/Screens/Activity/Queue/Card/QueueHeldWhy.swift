import SwiftUI
import FusionhaKit

/// The open "Why it's held" panel (web `HeldWhyDetail`). A proven mislabel
/// shows the facts grid, the block-group proof strip (only while the server
/// says the prompt is due) and "Import anyway" / "Blocklist this release";
/// any other hold shows claimed vs on disk and the verdict.
struct HeldWhy: View {
    let item: QueueItem
    let detail: HeldDetail
    /// The proof strip's evidence; nil until loaded or when not offered.
    let evidence: ReleaseGroupEvidence?
    let canBlockGroup: Bool
    let onImportAnyway: () -> Void
    let onBlockGroup: (String) -> Void
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @State private var blocklisting = false

    private var proven: Bool { HeldCopy.isProvenMislabel(detail) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if proven {
                QueueMislabelFactsGrid(detail: detail, indexer: item.indexer)
                if let strip = proofStrip { strip }
                actionsRow
            } else {
                plainLines
            }
            if let release = item.releaseTitle {
                Text(release)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.dim)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var proofStrip: AnyView? {
        guard canBlockGroup, detail.releaseBlocklisted == true, let group = detail.releaseGroup,
              let evidence, evidence.prompt.shouldPrompt else { return nil }
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text(MislabelFacts.proofSentence(group: group, count: evidence.mislabeledCount))
                    .font(.system(size: 13)).foregroundStyle(Theme.txt)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Block \(group)…", systemImage: "nosign") { onBlockGroup(group) }
                    .buttonStyle(ActButtonStyle(kind: .danger))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .actWash(Theme.danger, mono: .danger, radius: 10, base: Theme.panel)
        )
    }

    private var actionsRow: some View {
        let blocked = detail.releaseBlocklisted == true
        return ActFlow(spacing: 8, lineSpacing: 8) {
            Button("Import anyway", action: onImportAnyway)
                .buttonStyle(ActButtonStyle(kind: .subtle))
            Button("Blocklist this release", systemImage: "nosign") {
                blocklisting = true
                Task {
                    await ActActions.blocklist(model.client, toaster, BlocklistCreate(downloadId: item.id, search: false))
                    blocklisting = false
                }
            }
            .buttonStyle(ActButtonStyle(kind: .subtle))
            .disabled(blocked || blocklisting)
            .accessibilityHint(blocked ? "Already blocklisted automatically" : "")
        }
    }

    private var plainLines: some View {
        VStack(alignment: .leading, spacing: 4) {
            if detail.mislabeled == true, let probed = detail.probedQuality {
                let res = detail.probedResolution.map { " (\($0.w)×\($0.h))" } ?? ""
                line("Release claimed:", "\(detail.claimedQuality ?? "unknown") · mislabeled — actually \(probed)\(res)")
            } else {
                line("Release claimed:", detail.claimedQuality ?? "unknown")
            }
            if let current = detail.currentQuality {
                line("On disk:", "\(current) (\(detail.currentGroup ?? "no group"), CF \(detail.currentCf.map(String.init) ?? "—"))")
            }
            if detail.kind == "mislabeled_resolution" {
                line("Verdict:", "the release name doesn’t match the file")
            } else {
                line("Verdict:", "not an upgrade (\(detail.verdict.map(HeldCopy.verdictLabel) ?? "not an upgrade"))")
            }
        }
    }

    private func line(_ k: String, _ v: String) -> some View {
        (Text(k + " ").foregroundColor(Theme.dim) + Text(v).foregroundColor(Theme.txt))
            .font(.system(size: 12))
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The mislabel facts grid: Release says · Measured · On disk now · Release CF · Outcome.
struct QueueMislabelFactsGrid: View {
    let detail: HeldDetail
    let indexer: String?

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 6) {
            ForEach(MislabelFacts.rows(detail, indexer: indexer), id: \.label) { row in
                GridRow {
                    Text(row.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.dim)
                        .gridColumnAlignment(.leading)
                    Text(row.value)
                        .font(.system(size: 12, weight: row.bad ? .semibold : .regular))
                        .foregroundStyle(row.bad ? Theme.danger : Theme.txt)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
