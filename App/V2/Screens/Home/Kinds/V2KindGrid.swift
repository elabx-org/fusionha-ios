import SwiftUI
import FusionhaKit

/// A kind on a wide page (Home mock, open): its heading and count, then six
/// of its newest posters as a three-column mini grid. Kinds sit side by side
/// as columns (`V2HomeKinds`).
struct V2KindGrid: View {
    let kind: V2HomeKind
    let open: () -> Void
    @State private var width: CGFloat = 0

    private static let gap: CGFloat = 12

    private var cell: CGFloat? {
        width > 0 ? ((width - 2 * Self.gap) / 3).rounded(.down) : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            V2KindHead(kind: kind, open: open)
            Grid(alignment: .topLeading, horizontalSpacing: Self.gap, verticalSpacing: 14) {
                ForEach(rows, id: \.first?.id) { row in
                    GridRow {
                        ForEach(row) { item in
                            V2PosterCard(item: item, artWidth: cell, showsMeta: false)
                                .frame(width: cell)
                        }
                    }
                }
            }
        }
        // The column's own width (not the grid's, which follows its cells).
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    private var rows: [[MediaItem]] {
        let six = Array(kind.items.prefix(6))
        return stride(from: 0, to: six.count, by: 3).map { Array(six[$0..<min($0 + 3, six.count)]) }
    }
}

/// The kinds and the All titles card on a wide page: two to a row.
struct V2HomeKinds: View {
    let data: V2HomeData
    let open: (V2AllTitlesEntry) -> Void

    private enum Cell: Identifiable {
        case kind(V2HomeKind)
        case all
        var id: String {
            switch self {
            case .kind(let k): return k.kind.rawValue
            case .all: return "all"
            }
        }
    }

    var body: some View {
        let cells = data.kinds.map(Cell.kind) + [.all]
        let pairs = stride(from: 0, to: cells.count, by: 2).map { Array(cells[$0..<min($0 + 2, cells.count)]) }
        VStack(alignment: .leading, spacing: 30) {
            ForEach(pairs, id: \.first?.id) { pair in
                V2HomePair {
                    view(pair[0])
                } trailing: {
                    if pair.count > 1 { view(pair[1]) }
                }
            }
        }
    }

    @ViewBuilder
    private func view(_ cell: Cell) -> some View {
        switch cell {
        case .kind(let k):
            V2KindGrid(kind: k) { open(.kind(k.kind)) }
        case .all:
            VStack(alignment: .leading, spacing: 10) {
                V2HomeSectionHead(title: "Everything")
                V2AllTitlesCard(data: data) { open(.everything) }
            }
        }
    }
}
