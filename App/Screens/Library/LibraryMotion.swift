import SwiftUI

// MARK: - Library motion (the owner's Duo motion brief)

/// The grid's entrance: when titles first arrive, and when a kind, tier,
/// status or other filter changes the set, the first rows rise in a short
/// stagger (a ~0.35 s spring, no bounce). Only those rows, and only for a
/// moment: rows the scroll creates later, or re-creates on a jump back to
/// the top, never replay it. A background refresh of the same set is still.
struct LibraryEntrance: Equatable {
    static let rows = 6
    static let window: Duration = .milliseconds(1200)

    private(set) var generation = 0
    private(set) var rowIds: [String] = []
    private var key: String?

    /// Starts a new entrance when the set's shape changes; true when it did.
    mutating func update(key next: String, rows: [LibraryRowModel]) -> Bool {
        defer { key = next }
        guard next != key, !rows.isEmpty else { return false }
        generation &+= 1
        rowIds = rows.prefix(Self.rows).map(\.id)
        return true
    }

    /// The entrance window closed (unless a newer one started).
    mutating func end(_ generation: Int) {
        if generation == self.generation { rowIds = [] }
    }

    func index(of id: String) -> Int? { rowIds.firstIndex(of: id) }
}

private struct EntranceRow: ViewModifier {
    let index: Int?
    let generation: Int
    @Environment(\.motionEnabled) private var motion
    @State private var seen = -1

    private var hidden: Bool { motion && index != nil && seen != generation }

    func body(content: Content) -> some View {
        content
            .opacity(hidden ? 0 : 1)
            .offset(y: hidden ? 22 : 0)
            .onChange(of: generation, initial: true) { settle() }
    }

    private func settle() {
        guard let index, motion else { seen = generation; return }
        withAnimation(.spring(duration: 0.35, bounce: 0).delay(Double(index) * 0.05)) { seen = generation }
    }
}

/// Browsing: a row coming up from the bottom edge grows and brightens into
/// place, so the grid feels alive as it scrolls. Render-only (no layout or
/// body work per frame); the top edge stays still under the glass bars.
private struct BrowseRow: ViewModifier {
    @Environment(\.motionEnabled) private var motion

    func body(content: Content) -> some View {
        if motion {
            content.scrollTransition(topLeading: .identity, bottomTrailing: .interactive, axis: .vertical) { view, phase in
                view
                    .scaleEffect(phase.isIdentity ? 1 : 0.94, anchor: .top)
                    .opacity(phase.isIdentity ? 1 : 0.4)
            }
        } else {
            content
        }
    }
}

extension View {
    /// A Library grid row: the entrance stagger (when it's one of the first
    /// rows of a new set) and the browse effect.
    func libraryRowMotion(_ entrance: LibraryEntrance, id: String) -> some View {
        modifier(EntranceRow(index: entrance.index(of: id), generation: entrance.generation))
            .modifier(BrowseRow())
    }
}

// MARK: - The open Duo's title swipe (gesture 3)

extension LibraryDerived {
    /// The grid row holding title `id` (rows carry their first title in their id).
    func rowId(holding id: Int) -> String? {
        for row in rows {
            switch row {
            case .items(let items) where items.contains(where: { $0.id == id }): return row.id
            case .tableRow(let item, _) where item.id == id: return row.id
            default: continue
            }
        }
        return nil
    }
}
