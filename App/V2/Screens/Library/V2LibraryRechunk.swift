import Foundation
import FusionhaKit

/// The open Duo changes the Library's column count as a title opens beside
/// it (the full width to a third) and closes again. Only the rows depend on
/// the columns: the filtering, sorting, counts, shelf and home stay as they
/// are, so a columns-only change re-chunks the visible titles instead of
/// re-deriving all of them (`LibraryInputs.derive` sorts the whole library).
struct V2LibraryDeriveKey: Equatable {
    var inputs: LibraryInputs
    var unmonitoredOnly: Bool
    var network: String

    init(_ inputs: LibraryInputs, unmonitoredOnly: Bool, network: String) {
        var any = inputs
        any.columns = 0
        self.inputs = any
        self.unmonitoredOnly = unmonitoredOnly
        self.network = network
    }
}

extension LibraryDerived {
    /// The same titles, in the same order, in rows of `inputs.columns`.
    /// Nil when the rows don't depend on the columns (the compact list).
    func rechunked(_ inputs: LibraryInputs, library: [MediaItem]) -> LibraryDerived? {
        guard !inputs.compact else { return nil }
        let byId = Dictionary(library.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let visible = visibleIds.compactMap { byId[$0] }
        guard visible.count == visibleIds.count else { return nil }
        var next = self
        next.columns = inputs.columns
        if inputs.group {
            next.rows = LibraryRowModel.grouped(visible, columns: inputs.columns)
        } else if inputs.sort == .title {
            (next.rows, next.alpha) = LibraryRowModel.alpha(visible, columns: inputs.columns,
                                                            headers: inputs.letterHeaders)
        } else {
            next.rows = LibraryRowModel.plain(visible, columns: inputs.columns)
        }
        return next
    }
}
