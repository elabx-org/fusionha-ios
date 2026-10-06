import SwiftUI
import FusionhaKit

/// The A–Z poster grid, window-virtualized like the web's `VirtualAlphaGrid`:
/// a spacer of the true grid height with only the window's rows placed at
/// their known offsets. Each row is exactly its layout height, so a jump to a
/// letter lands on a computed offset and the lazy-stack estimate (which left
/// the screen blank for a frame on a far jump) is gone.
struct LibraryWindowedGrid: View {
    let rows: [LibraryRowModel]
    let columns: Int
    let window: LibraryGridWindow
    @Environment(\.railConsolidate) private var consolidate

    var body: some View {
        let _ = PerfCount.hit("LibraryWindowedGrid.body")
        let layout = window.layout
        ZStack(alignment: .top) {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: CGFloat(layout.totalHeight))
            // Identified by row id: the jump's `scrollTo` target and the scroll-spy ids.
            ForEach(window.rendered.filter { rows.indices.contains($0) }.map { Placed(index: $0, id: rows[$0].id) }) { row in
                placed(row.index)
            }
        }
        .scrollTargetLayout()
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.bounds(of: .scrollView) ?? .zero
        } action: { rect in
            window.track(rect)
        }
    }

    private struct Placed: Identifiable {
        let index: Int
        let id: String
    }

    @ViewBuilder
    private func placed(_ index: Int) -> some View {
        if case .items(let items) = rows[index] {
            let slots = LibraryGridRow.slots(items, consolidate: consolidate)
            let y = window.offset(of: index)
            LibraryGridRow(items: items, columns: columns)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    window.observe(slots: slots, height: height)
                }
                .frame(height: window.height(of: index), alignment: .top)
                .alignmentGuide(.top) { _ in -y }
        }
    }
}
