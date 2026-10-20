import SwiftUI
import FusionhaKit

/// One file (the web's `PhoneRow`): a tick on every row (select is not
/// import), then three lines that open the row: code and title; quality,
/// version, size and status; and the dim video · audio · group line.
struct MIRowView: View {
    let row: ManualImportRow
    @Binding var openId: Int?
    /// The Duo split's list: a tap shows the file in the detail pane (`openId`
    /// is then the pane's row) instead of opening it in place.
    var picksDetail = false
    @Environment(ManualImportSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var open: Bool { openId == row.rowId }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                checkbox
                Button {
                    if picksDetail { openId = row.rowId; return }
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { openId = open ? nil : row.rowId }
                } label: { lines }
                .buttonStyle(.plain)
                .accessibilityHint(picksDetail ? "Shows the file beside the list" : open ? "Closes the file" : "Opens the file")
                .accessibilityAddTraits(picksDetail && open ? .isSelected : [])
            }
            notes
            if open && !picksDetail {
                MIRowBody(row: row)
                    .padding(.top, 6)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 10)
        .padding(.trailing, 12)
        .padding(.leading, 4)
        .actWash(wash, radius: Theme.radius, base: Theme.panel)
    }

    /// A status wash over the solid row (content stays solid, never glass). The
    /// split's current row is an ambient accent tint, never a border.
    private var wash: StatusTone? {
        if picksDetail && open { return StatusTone(color: Theme.i2) }
        guard !row.committed else { return nil }
        switch row.status {
        case "no_match": return StatusTone(.danger)
        case "needs_attention": return StatusTone(.miss)
        default: return nil
        }
    }

    private var checkbox: some View {
        let on = session.selected.contains(row.rowId)
        return Button { session.toggle(row) } label: {
            Image(systemName: row.committed ? "checkmark.seal.fill" : on ? "checkmark.square.fill" : "square")
                .font(.system(size: 20))
                .foregroundStyle(row.committed ? Theme.done : on ? Theme.i1 : Theme.dim)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .disabled(row.committed)
        .accessibilityLabel("Select \(row.filename)")
        .accessibilityValue(on ? "Selected" : "Not selected")
    }

    private var lines: some View {
        VStack(alignment: .leading, spacing: 4) {
            titleLine
            HStack(spacing: 8) {
                Text(DetailText.quality(row.quality ?? "UNKNOWN"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(row.quality == nil ? Theme.miss : Theme.txt)
                if row.match.itemId != nil, let tier = QualityTier(rawValue: row.target.tier) { TierPill(tier: tier) }
                Text(DetailText.bytes(row.size)).font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                Spacer(minLength: 0)
                MIStatusBadge(row: row)
            }
            Text(ManualImportCompare.summaryLine(row))
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(Theme.dim)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
        .contentShape(Rectangle())
    }

    private var titleLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            MIRowTitle(row: row)
            if !picksDetail {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.dim)
                    .rotationEffect(.degrees(open ? 180 : 0))
            }
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(Theme.txt)
    }

    private var notes: some View { MIRowNotes(row: row) }
}

/// Under a row: a rescue's finding chips and actions, then its advisory,
/// error and warning lines (the card row and the table row share them).
struct MIRowNotes: View {
    let row: ManualImportRow
    var indent: CGFloat = 48
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        // A held row of a rescue shows finding chips and its actions (0.4.202); the sentence moves into them.
        let rescue = session.tally(for: row) != nil
        if rescue {
            MIFindingLine(row: row).padding(.leading, indent).padding(.top, 6)
        }
        let lines: [(String, Color)] = [
            (rescue ? nil : ManualImportRules.advisory(row)).map { ($0, Theme.miss) },
            session.rowErrors[row.rowId].map { ($0, Theme.danger) },
            session.rowWarnings[row.rowId].map { ($0, Theme.miss) },
        ].compactMap { $0 }
        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
            Text(line.0)
                .font(.system(size: 12.5))
                .foregroundStyle(line.1)
                .padding(.leading, indent)
                .padding(.top, 4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
