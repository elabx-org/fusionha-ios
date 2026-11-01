import SwiftUI
import FusionhaKit

/// iPhone Duo with both screens open (web `SplitBody`, mock screen 6): the
/// list and its import footer on the leading pane, the chosen file's detail on
/// the trailing one. Each pane scrolls on its own. In book pose the panes meet
/// at the fold's gutter (`lead`, `gap`); flat (`gap` 0) and in a split-capable
/// sheet a hairline splits them, the same structure (D2-A). The chosen file is
/// the tapped one while it shows, else the first held file, else the first
/// shown (`useSplitDetailRow`). While files are ticked in a scan the bulk bar
/// serves, the trailing pane is the decision panel instead (until a file is
/// tapped) and the footer steps aside. A held scan with nothing ticked and no
/// file tapped shows "Nothing selected" (web `NothingSelectedPanel`).
struct MISplitBody: View {
    let scan: ManualImportScan
    @Binding var detailId: Int?
    @Binding var folded: Set<String>
    var lead: CGFloat?
    var gap: CGFloat = 0
    let onRetryProbes: () -> Void
    @Environment(ManualImportSession.self) private var session

    private var deciding: Bool { session.barShows && session.tickedCount > 0 }

    var body: some View {
        let shown = scan.rows.filter(session.shows)
        let row = shown.first { $0.rowId == detailId } ?? shown.first { $0.held != nil } ?? shown.first
        let panel = deciding && detailId == nil
        let nothing = scan.isRescue && session.selected.isEmpty && detailId == nil && !shown.isEmpty
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                ScrollView {
                    MIScanList(scan: scan, rowMode: .pick, openId: pickBinding(panel || nothing ? nil : row), folded: $folded,
                               onRetryProbes: onRetryProbes)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.immediately)
                if !deciding { MIFooter() }
            }
            .frame(width: lead)
            .frame(maxWidth: lead == nil ? .infinity : nil)
            if lead == nil || gap == 0 {
                Rectangle().fill(Theme.line).frame(width: 1).ignoresSafeArea(edges: .bottom)
            } else {
                Color.clear.frame(width: gap)
            }
            ScrollView {
                if panel {
                    MIDecidePanel()
                } else if nothing {
                    MINothingSelectedPanel()
                } else if let row {
                    if deciding { backToPanel }
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
        .onChange(of: session.selected) {
            // A tick brings the decision panel back.
            if session.barShows { detailId = nil }
        }
    }

    private var backToPanel: some View {
        Button("Back to \(session.tickedCount) selected", systemImage: "chevron.backward") { detailId = nil }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.accentText)
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
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
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.dim)
                MIRowTitle(row: row)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.txt)
                HStack(spacing: 10) {
                    Text(DetailText.quality(row.quality ?? "UNKNOWN"))
                    if row.match.itemId != nil, let tier = QualityTier(rawValue: row.target.tier) { TierPill(tier: tier) }
                    Text(DetailText.bytes(row.size))
                    MIStatusBadge(row: row)
                    Text(ManualImportRules.statusLong(row)).lineLimit(1)
                }
                .font(.caption)
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
