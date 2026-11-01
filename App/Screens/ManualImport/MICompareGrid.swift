import SwiftUI
import FusionhaKit

/// Current vs this file, one attribute a line under a Current / This file
/// header; this file's value carries the direction. VoiceOver reads each line
/// as one sentence with both values.
struct MICompareGrid: View {
    let rows: [ManualImportCompare.WhichRow]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 5) {
            GridRow {
                Color.clear.frame(width: 1, height: 1).gridCellUnsizedAxes([.horizontal, .vertical])
                Text("Current").accessibilityHidden(true)
                Text("This file").accessibilityHidden(true)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.dim)
            ForEach(rows, id: \.label) { r in
                GridRow {
                    // The label cell speaks the whole line; the value cells are hidden.
                    Text(r.label).foregroundStyle(Theme.mut).accessibilityLabel(Self.spoken(r))
                    Text(r.current).foregroundStyle(Theme.txt).accessibilityHidden(true)
                    HStack(spacing: 3) {
                        if r.tone != .same {
                            Image(systemName: r.tone == .up ? "arrow.up" : "arrow.down").font(.caption2.weight(.bold))
                        }
                        Text(r.incoming)
                    }
                    .foregroundStyle(r.tone == .up ? Theme.done : r.tone == .down ? Theme.danger : Theme.txt)
                    .accessibilityHidden(true)
                }
                .font(.caption)
            }
        }
    }

    static func spoken(_ r: ManualImportCompare.WhichRow) -> String {
        let dir = r.tone == .up ? ", better" : r.tone == .down ? ", worse" : ""
        return "\(r.label): current \(r.current), this file \(r.incoming)\(dir)"
    }
}

/// The upgrade compare (no choice to make): the changed attributes only.
struct MICompareTable: View {
    let row: ManualImportRow
    let title: String

    var body: some View {
        if let rows = ManualImportCompare.whichFileRows(row), !rows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
                MICompareGrid(rows: rows.filter(\.changed))
            }
        }
    }
}
