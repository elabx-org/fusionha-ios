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
            if let strip = ManualImportHeldStrip(scan: scan, decide: session.plan.need) { MIHeldStripView(strip: strip) }
            MIPackProgress()
            MIVerdictStrip(rows: scan.rows, filter: $session.filter, probing: scan.probePending ?? 0,
                           stalled: session.probeStalled) {
                session.retryProbes()
                onRetryProbes()
            }
            let blocks = ManualImportBlock.group(scan.rows)
            MIMatchBanner(blocks: blocks, filter: $session.filter)
            ForEach(blocks) { block in
                let shown = block.rows.filter(session.filter.matches)
                if !shown.isEmpty {
                    MITitleSection(block: block, rows: shown, folded: foldBinding(block.key), openId: $openId,
                                   rowMode: rowMode)
                }
            }
            if blocks.allSatisfy({ !$0.rows.contains(where: session.filter.matches) }) {
                Button("No files match this filter. Show all") { session.filter = .all }
                    .buttonStyle(ActButtonStyle(kind: .ghost))
            }
        }
    }

    private func foldBinding(_ key: String) -> Binding<Bool> {
        Binding(get: { folded.contains(key) },
                set: { if $0 { folded.insert(key) } else { folded.remove(key) } })
    }
}

/// iPhone Duo with both screens open (web `SplitBody`, mock screen 6): the
/// list and its import footer on the leading half, the chosen file's detail on
/// the trailing half, a hairline between. Each pane scrolls on its own. The
/// chosen file is the tapped one while it shows, else the first held file,
/// else the first shown (`useSplitDetailRow`).
struct MISplitBody: View {
    let scan: ManualImportScan
    @Binding var detailId: Int?
    @Binding var folded: Set<String>
    let onRetryProbes: () -> Void
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        let shown = scan.rows.filter(session.filter.matches)
        let row = shown.first { $0.rowId == detailId } ?? shown.first { $0.held != nil } ?? shown.first
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                ScrollView {
                    MIScanList(scan: scan, rowMode: .pick, openId: pickBinding(row), folded: $folded,
                               onRetryProbes: onRetryProbes)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.immediately)
                MIFooter()
            }
            .frame(maxWidth: .infinity)
            Rectangle().fill(Theme.line).frame(width: 1).ignoresSafeArea(edges: .bottom)
            ScrollView {
                if let row {
                    MIDetailPane(row: row).id(row.rowId)
                } else {
                    Text("Select a file")
                        .font(.subheadline).foregroundStyle(Theme.dim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: shown.map(\.rowId)) { _, ids in
            // A choice that fell out (imported, filtered away) is let go.
            if let id = detailId, !ids.contains(id) { detailId = nil }
        }
    }

    /// The list marks the file the pane shows (the fallback included).
    private func pickBinding(_ row: ManualImportRow?) -> Binding<Int?> {
        Binding(get: { row?.rowId }, set: { detailId = $0 })
    }
}

/// The right screen (web `DetailPane`): the file's code · title, its title
/// line, quality · version · size · status, any warning, then its body.
struct MIDetailPane: View {
    let row: ManualImportRow
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text([ManualImportRules.episodeCode(row), row.match.title].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.dim)
                MIRowTitle(row: row)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                HStack(spacing: 10) {
                    Text(DetailText.quality(row.quality ?? "UNKNOWN"))
                    if row.match.itemId != nil, let tier = QualityTier(rawValue: row.target.tier) { TierPill(tier: tier) }
                    Text(DetailText.bytes(row.size))
                    MIStatusBadge(row: row)
                    Text(ManualImportRules.statusLong(row)).lineLimit(1)
                }
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.dim)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
            VStack(alignment: .leading, spacing: 12) {
                MIRowNotes(row: row, indent: 0)
                MIRowBody(row: row, indent: 0)
            }
            .padding(14)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("File details")
    }
}
