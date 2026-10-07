import SwiftUI
import FusionhaKit

/// The numbering preview's body: notable rows grouped by season
/// (`Renumbered E3 → E4 Title`), then what happens to files and phantoms.
struct NumberingDiffList: View {
    let preview: NumberingPreview
    let sourceLabel: String

    var body: some View {
        let seasons = NumberingCopy.notableBySeason(preview.rows ?? [])
        VStack(alignment: .leading, spacing: 12) {
            if seasons.isEmpty {
                DialogEmpty("\(sourceLabel) numbering matches what's stored — nothing to renumber.")
            }
            ForEach(seasons) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Text("Season \(group.season)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.mut)
                    ForEach(Array(group.rows.enumerated()), id: \.offset) { _, row in
                        NumberingRowView(row: row)
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
            FileList(heading: "\(relinked.count) \(relinked.count == 1 ? "file" : "files") will be re-linked to the corrected numbering — no re-download, no bytes moved.",
                     lines: relinked.map(\.path), tint: Theme.mut)
        }
        if !unparseable.isEmpty {
            FileList(heading: "\(unparseable.count) \(unparseable.count == 1 ? "file" : "files") couldn't be matched to a corrected slot — flagged for manual assignment, never guessed or dropped:",
                     lines: unparseable.map { "\($0.path) — \($0.reason ?? "")" }, tint: Theme.miss)
        }
        if !phantoms.isEmpty {
            Text("\(phantoms.count) phantom \(phantoms.count == 1 ? "episode" : "episodes") with no files will be removed.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.mut)
        }
    }
}

private struct NumberingRowView: View {
    let row: NumberingDiffRow

    private var tint: Color {
        switch row.kind {
        case "added": return Theme.done
        case "removed": return Theme.danger
        default: return Theme.edition
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(NumberingCopy.kindLabel(row.kind))
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(tint)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(tint.opacity(0.14), in: Capsule())
            Text("\(row.currentNumber.map { "E\($0)" } ?? "—") → \(row.alternateNumber.map { "E\($0)" } ?? "—")")
                .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.txt)
            // The title apply keeps: the current one, else the added row's alternate.
            Text(row.currentTitle ?? row.alternateTitle ?? "")
                .font(.system(size: 13))
                .foregroundStyle(Theme.mut)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 9))
    }
}

private struct FileList: View {
    let heading: String
    let lines: [String]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(heading)
                .font(.system(size: 13))
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
