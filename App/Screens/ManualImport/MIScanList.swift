import SwiftUI
import FusionhaKit

/// The scan's list (web `ManualImportBody` chrome + blocks): the source bar for
/// a folder scan, the held strip, pack progress, the verdict strip, the match
/// banner, then one section per title. The phone cards, the Duo split's list
/// and the desktop table all use it; only `rowMode` differs.
struct MIScanList: View {
    let scan: ManualImportScan
    let rowMode: MIRowMode
    @Binding var openId: Int?
    @Binding var folded: Set<String>
    /// The probes were retried: the sheet restarts its poll.
    let onRetryProbes: () -> Void
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        @Bindable var session = session
        LazyVStack(alignment: .leading, spacing: 10) {
            if session.folderMode { MISourceBar() }
            if !scan.sourcePath.isEmpty { MISourceLine(path: scan.sourcePath) }
            if scan.rows.isEmpty {
                noVideos
            } else {
                if let strip = ManualImportHeldStrip(scan: scan, decide: session.plan.need, tallies: session.tallies) { MIHeldStripView(strip: strip) }
                MIPackProgress()
                MIVerdictStrip(rows: scan.rows, filter: $session.filter, probing: scan.probePending ?? 0,
                               stalled: session.probeStalled, isDone: session.isDone) {
                    session.retryProbes()
                    onRetryProbes()
                }
                let blocks = ManualImportBlock.group(scan.rows)
                MIMatchBanner(blocks: blocks, filter: $session.filter)
                ForEach(blocks) { block in
                    let shown = block.rows.filter(session.shows)
                    if !shown.isEmpty {
                        MITitleSection(block: block, rows: shown, folded: foldBinding(block.key), openId: $openId,
                                       rowMode: rowMode)
                    }
                }
                if blocks.allSatisfy({ !$0.rows.contains(where: session.shows) }) { filterEmpty }
            }
        }
    }

    /// A scan that found no video files: say so, not "nothing matches this filter".
    private var noVideos: some View {
        ContentUnavailableView {
            Label(ManualImportCopy.noVideos(folder: session.folderMode), systemImage: "film")
        } description: {
            if session.folderMode { Text("Pick another folder and scan again.") }
        }
    }

    /// Rows exist but the filter shows none (web `manual-filter-empty`).
    private var filterEmpty: some View {
        HStack(spacing: 10) {
            Text(ManualImportCopy.filterEmpty).font(.subheadline).foregroundStyle(Theme.mut)
            Button("Show all") { session.filter = .all }
                .buttonStyle(ActButtonStyle(kind: .ghost))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func foldBinding(_ key: String) -> Binding<Bool> {
        Binding(get: { folded.contains(key) },
                set: { if $0 { folded.insert(key) } else { folded.remove(key) } })
    }
}
