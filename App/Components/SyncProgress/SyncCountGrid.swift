import SwiftUI
import FusionhaKit

/// A row of small count tiles (web `CountGrid`): a zero reads dim, and a
/// number that grows rolls up with the system numeric transition (instant
/// under Reduce Motion).
struct SyncCountGrid: View {
    let cells: [SyncProgress.Cell]
    var label = "Outcomes so far"
    @Environment(\.accessibilityReduceMotion) private var systemReduce
    @Environment(\.actReduceMotion) private var appReduce

    var body: some View {
        HStack(spacing: 6) {
            ForEach(cells) { cell in
                VStack(spacing: 1) {
                    Text("\(cell.value)")
                        .font(.system(size: 15, weight: .heavy).monospacedDigit())
                        .foregroundStyle(cell.value == 0 ? Theme.dim : Theme.txt)
                        .contentTransition(.numericText(value: Double(cell.value)))
                    Text(cell.label)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.mut)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .padding(.horizontal, 2)
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(cell.label): \(cell.value)")
            }
        }
        .animation(systemReduce || appReduce ? nil : .snappy, value: cells)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

/// One source's five counts: Requested · In library · Queued · Waiting · Skipped.
struct SyncCountsView: View {
    let counts: SourceCounts?

    var body: some View {
        SyncCountGrid(cells: SyncProgress.cells(counts))
    }
}
