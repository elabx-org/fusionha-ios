import SwiftUI
import FusionhaKit

/// Current vs this file, one attribute a line; this file's value carries the direction.
struct MICompareGrid: View {
    let rows: [ManualImportCompare.WhichRow]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 5) {
            ForEach(rows, id: \.label) { r in
                GridRow {
                    Text(r.label).foregroundStyle(Theme.mut)
                    Text(r.current).foregroundStyle(Theme.txt)
                    HStack(spacing: 3) {
                        if r.tone != .same {
                            Image(systemName: r.tone == .up ? "arrow.up" : "arrow.down").font(.system(size: 11, weight: .bold))
                        }
                        Text(r.incoming)
                    }
                    .foregroundStyle(r.tone == .up ? Theme.done : r.tone == .down ? Theme.danger : Theme.txt)
                }
                .font(.system(size: 12.5))
            }
        }
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
