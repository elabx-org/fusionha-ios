import SwiftUI
import FusionhaKit

/// Fix episode numbering in v2's form sheet (Look Pass family 1): one card
/// per season with a row per change (Renumbered / New / Removed, E→E, the
/// title), then what happens to files and phantoms. The same facts as v1's
/// `NumberingDiffList`; renumbered is a quiet tag, new and removed keep
/// their state colour. Paths stay mono and selectable.
struct V2NumberingDiffList: View {
    let preview: NumberingPreview
    let sourceLabel: String

    var body: some View {
        let seasons = NumberingCopy.notableBySeason(preview.rows ?? [])
        VStack(alignment: .leading, spacing: 18) {
            if seasons.isEmpty {
                DialogEmpty("\(sourceLabel) numbering matches what's stored — nothing to renumber.")
            }
            ForEach(seasons) { group in
                V2FormSection(label: "Season \(group.season)") {
                    ForEach(Array(group.rows.enumerated()), id: \.offset) { index, row in
                        if index > 0 { V2FormDivider() }
                        V2NumberingRow(row: row).v2FormRow()
                    }
                }
            }
            summary
        }
    }

    @ViewBuilder
    private var summary: some View {
        let relinked = preview.relinked ?? []
        let unparseable = preview.unparseable ?? []
        let phantoms = preview.removedPhantoms ?? []
        if !relinked.isEmpty {
            files("\(relinked.count) \(relinked.count == 1 ? "file" : "files") will be re-linked to the corrected numbering. No re-download, no bytes moved.",
                  lines: relinked.map(\.path), tint: Theme.mut)
        }
        if !unparseable.isEmpty {
            files("\(unparseable.count) \(unparseable.count == 1 ? "file" : "files") couldn't be matched to a corrected slot — flagged for manual assignment, never guessed or dropped:",
                  lines: unparseable.map { "\($0.path): \($0.reason ?? "")" }, tint: Theme.missText)
        }
        if !phantoms.isEmpty {
            Text("\(phantoms.count) phantom \(phantoms.count == 1 ? "episode" : "episodes") with no files will be removed.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.mut)
                .padding(.horizontal, 4)
        }
    }

    private func files(_ heading: String, lines: [String], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(heading)
                .font(.system(size: 13))
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                V2FormPath(path: line, color: Theme.mut)
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct V2NumberingRow: View {
    let row: NumberingDiffRow

    private var tint: Color? {
        switch row.kind {
        case "added": return Theme.doneText
        case "removed": return Theme.dangerText
        default: return nil
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(NumberingCopy.kindLabel(row.kind))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint ?? Theme.txt)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background((tint ?? Theme.txt).opacity(0.10), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text("\(row.currentNumber.map { "E\($0)" } ?? "—") → \(row.alternateNumber.map { "E\($0)" } ?? "—")")
                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.txt)
            // The title apply keeps: the current one, else the added row's alternate.
            Text(row.currentTitle ?? row.alternateTitle ?? "")
                .font(.system(size: 15))
                .foregroundStyle(Theme.mut)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
