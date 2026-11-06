import SwiftUI

extension View {
    /// A scroll view whose host the fold replaces (a right page becoming a
    /// sheet, a sheet becoming pages) keeps its offset in a model that
    /// outlives it: written while it scrolls, read back when the next host
    /// appears. Reports before the restore are ignored, so the new host's
    /// first frame at the top can't overwrite the kept offset.
    func keepsScrollOffset(read: @escaping () -> CGFloat, write: @escaping (CGFloat) -> Void) -> some View {
        modifier(FoldScrollOffset(read: read, write: write))
    }
}

private struct FoldScrollOffset: ViewModifier {
    let read: () -> CGFloat
    let write: (CGFloat) -> Void
    @State private var position = ScrollPosition(edge: .top)
    @State private var armed = false

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top
            } action: { _, y in
                if armed { write(max(0, y)) }
            }
            .onAppear {
                let y = read()
                Task { @MainActor in
                    if y > 1 {
                        // Once the new host has laid its content out.
                        try? await Task.sleep(for: .milliseconds(120))
                        position.scrollTo(y: y)
                        try? await Task.sleep(for: .milliseconds(80))
                    }
                    armed = true
                }
            }
    }
}
