import SwiftUI
import FusionhaKit

/// The desktop table's one grid (web `columns.ts` `COLUMNS`): select · Episode ·
/// Quality · Version · Video · Audio · Group · service · Size · Status · open.
/// Narrow (under 1100, `COLUMNS_NARROW`) drops Audio and Group · service; the
/// opened row still shows them.
enum MITableColumns {
    static let check: CGFloat = 44
    static let quality: CGFloat = 116
    static let version: CGFloat = 82
    static let video: CGFloat = 196
    static let audio: CGFloat = 120
    static let group: CGFloat = 140
    static let size: CGFloat = 64
    static let status: CGFloat = 40
    static let chevron: CGFloat = 28
    static let spacing: CGFloat = 8
}

/// A block's column head (web `ColumnHead`).
struct MITableHead: View {
    let narrow: Bool

    var body: some View {
        HStack(spacing: MITableColumns.spacing) {
            Color.clear.frame(width: MITableColumns.check, height: 1)
            label("Episode").frame(minWidth: 160, maxWidth: .infinity, alignment: .leading)
            label("Quality").frame(width: MITableColumns.quality, alignment: .leading)
            label("Version").frame(width: MITableColumns.version, alignment: .leading)
            label("Video").frame(width: MITableColumns.video, alignment: .leading)
            if !narrow {
                label("Audio").frame(width: MITableColumns.audio, alignment: .leading)
                label("Group · service").frame(width: MITableColumns.group, alignment: .leading)
            }
            label("Size").frame(width: MITableColumns.size, alignment: .trailing)
            Color.clear.frame(width: MITableColumns.status + MITableColumns.chevron + MITableColumns.spacing, height: 1)
        }
        .padding(.trailing, 8)
        .accessibilityHidden(true)
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .heavy))
            .tracking(0.5)
            .foregroundStyle(Theme.dim)
            .lineLimit(1)
    }
}

/// One file as a table row (web `FileRow.tsx`): one line of cells, a tap
/// anywhere outside the box and status opens the row's drawer beneath it
/// (the same `MIRowBody` the phone opens in place). Cells read only; edits
/// live in the drawer's Import as fields.
struct MITableRow: View {
    let row: ManualImportRow
    let narrow: Bool
    @Binding var openId: Int?
    @Environment(ManualImportSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var open: Bool { openId == row.rowId }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: MITableColumns.spacing) {
                checkbox
                Button(action: toggle) { cells }
                    .buttonStyle(.plain)
                    .accessibilityHint(open ? "Closes the file" : "Opens the file")
                MIStatusBadge(row: row).frame(width: MITableColumns.status)
                Button(action: toggle) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.dim)
                        .rotationEffect(.degrees(open ? 180 : 0))
                        .frame(width: MITableColumns.chevron, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Details")
                .accessibilityValue(open ? "Expanded" : "Collapsed")
            }
            .padding(.trailing, 8)
            MIRowNotes(row: row, indent: MITableColumns.check + MITableColumns.spacing)
            if open {
                MIRowBody(row: row, indent: MITableColumns.check + MITableColumns.spacing)
                    .padding(.top, 8)
                    .padding(.trailing, 16)
                    .padding(.bottom, 6)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 2)
        .actWash(wash, radius: Theme.radius, base: Theme.panel)
    }

    private var cells: some View {
        HStack(spacing: MITableColumns.spacing) {
            MIRowTitle(row: row)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.txt)
                .frame(minWidth: 160, maxWidth: .infinity, alignment: .leading)
            Text(DetailText.quality(row.quality ?? "UNKNOWN"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(row.quality == nil ? Theme.miss : Theme.txt)
                .lineLimit(1)
                .frame(width: MITableColumns.quality, alignment: .leading)
            Group {
                if row.match.itemId != nil, let tier = QualityTier(rawValue: row.target.tier) {
                    TierPill(tier: tier)
                } else {
                    Text("—").foregroundStyle(Theme.dim)
                }
            }
            .frame(width: MITableColumns.version, alignment: .leading)
            mono(ManualImportTableCells.video(row)).frame(width: MITableColumns.video, alignment: .leading)
            if !narrow {
                mono(ManualImportTableCells.audio(row)).frame(width: MITableColumns.audio, alignment: .leading)
                mono(ManualImportTableCells.group(row)).frame(width: MITableColumns.group, alignment: .leading)
            }
            Text(DetailText.bytes(row.size))
                .font(.system(size: 12.5).monospacedDigit())
                .foregroundStyle(Theme.mut)
                .lineLimit(1)
                .frame(width: MITableColumns.size, alignment: .trailing)
        }
        .frame(minHeight: 46)
        .contentShape(Rectangle())
    }

    private func mono(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, design: .monospaced))
            .foregroundStyle(text == "—" || text == "no group in name" ? Theme.dim : Theme.mut)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private func toggle() {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { openId = open ? nil : row.rowId }
    }

    /// A status wash over the solid row, as on the phone card.
    private var wash: StatusTone? {
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
                .font(.system(size: 18))
                .foregroundStyle(row.committed ? Theme.done : on ? Theme.i1 : Theme.dim)
                .frame(width: MITableColumns.check, height: 44)
        }
        .buttonStyle(.plain)
        .disabled(row.committed)
        .accessibilityLabel("Select \(row.filename)")
        .accessibilityValue(on ? "Selected" : "Not selected")
    }
}
