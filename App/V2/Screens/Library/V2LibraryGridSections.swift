import Foundation
import FusionhaKit

/// The v2 poster grid's content, read off `LibraryDerived.rows`: the runs of
/// poster rows between their headers (status sections, letters), each run
/// one section of cells. The grid lays a section's cells out in columns
/// itself, so a column change (a title opening beside the Library on the
/// open Duo, the full width to a third) moves the same cards instead of
/// building new rows of them.
struct V2LibraryGridSection: Identifiable {
    enum Header {
        case status(CardStatus, Int)
        case letter(String, Int)
    }

    let id: String
    let header: Header?
    var cells: [V2LibraryGridCell] = []
}

/// One poster in the grid. Its id is the one its row would have if it led
/// one ("row-<title id>"), so the thumb's letter jumps, the anchor kept
/// across a column change and the title swipe all still find it by the
/// row ids `LibraryDerived` hands out, and it never changes with the columns.
struct V2LibraryGridCell: Identifiable {
    let item: MediaItem
    /// The id of the row this poster sits in now (its first title's).
    let rowId: String
    /// Its column in that row.
    let column: Int

    var id: String { "row-\(item.id)" }
}

extension V2LibraryGridSection {
    /// The grid's sections, in order. Empty for the compact list.
    static func sections(from rows: [LibraryRowModel]) -> [V2LibraryGridSection] {
        var sections: [V2LibraryGridSection] = []
        for row in rows {
            switch row {
            case .section(let status, let count):
                sections.append(V2LibraryGridSection(id: row.id, header: .status(status, count)))
            case .letter(let letter, let count):
                sections.append(V2LibraryGridSection(id: row.id, header: .letter(letter, count)))
            case .items(let items):
                if sections.isEmpty { sections.append(V2LibraryGridSection(id: "grid", header: nil)) }
                let rowId = row.id
                sections[sections.count - 1].cells += items.enumerated().map { column, item in
                    V2LibraryGridCell(item: item, rowId: rowId, column: column)
                }
            case .tableHeader, .tableRow:
                continue
            }
        }
        return sections
    }
}
