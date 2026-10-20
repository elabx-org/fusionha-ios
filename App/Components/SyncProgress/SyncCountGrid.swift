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
        // One row (the web's `repeat(N, minmax(0, 1fr))`) while every label fits
        // at 11 pt; narrower, the tiles wrap into even lines (3 + 2) instead of
        // truncating "In library" to "In l…".
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                ForEach(cells) { cell in tile(cell, fits: true) }
            }
            StretchWrapLayout(minItemWidth: 64, spacing: 6, lineSpacing: 6, balanced: true) {
                ForEach(cells) { cell in tile(cell, fits: false) }
            }
        }
        .animation(systemReduce || appReduce ? nil : .snappy, value: cells)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

    /// `fits`: the label keeps its whole width, so the one-row candidate only
    /// fits when nothing would truncate.
    private func tile(_ cell: SyncProgress.Cell, fits: Bool) -> some View {
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
                .fixedSize(horizontal: fits, vertical: false)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .padding(.horizontal, 2)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(cell.label): \(cell.value)")
    }
}

/// One source's five counts: Requested · In library · Queued · Waiting · Skipped.
struct SyncCountsView: View {
    let counts: SourceCounts?

    var body: some View {
        SyncCountGrid(cells: SyncProgress.cells(counts))
    }
}
