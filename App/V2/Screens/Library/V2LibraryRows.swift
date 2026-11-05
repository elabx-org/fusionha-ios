import SwiftUI
import FusionhaKit

/// The v2 Library's body under the home: the skeleton while the library
/// first loads, the could-not-load and empty messages, the no-match state,
/// or the lazy rows (`LibraryRowModel`: poster rows, status sections, the
/// compact list). Rows are flat so the scroll stays lazy and the thumb can
/// jump to any of them.
struct V2LibraryRows: View {
    let derived: LibraryDerived
    var tracks: [FoldColumns.Track]?
    let width: CGFloat
    let entrance: LibraryEntrance
    @Binding var compactSort: CompactSort
    let filters: V2LibraryFilters
    let query: String
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion

    var body: some View {
        if model.library.isEmpty {
            if !model.libraryLoaded {
                LibraryGridSkeleton(columns: derived.columns, tracks: tracks)
            } else if model.libraryError != nil {
                message("Your library could not be loaded. Check the backend and try again.")
            } else {
                message("Your library is empty. Use Add to search TMDB and start tracking a title in one or more versions (HD, 4K).")
            }
        } else if derived.rows.isEmpty || derived.titleCount == 0 {
            V2LibraryNoMatch(query: query, noun: noun, total: kindTotal) {
                withAnimation(motion ? .snappy : nil) {
                    filters.clearAll()
                    model.searchText = ""
                }
            }
        } else {
            rows
        }
    }

    private var rows: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(derived.rows) { row in
                switch row {
                case .section(let status, let count):
                    StatusSectionHeader(status: status, count: count)
                case .letter(let letter, let count):
                    LibraryLetterHeader(letter: letter, count: count)
                case .items(let items):
                    V2LibraryGridRow(items: items, columns: derived.columns, tracks: tracks, width: width)
                        .libraryRowEntrance(entrance, id: row.id)
                case .tableHeader:
                    V2LibraryListHeader(sort: compactSort) { column in
                        withAnimation(motion ? .snappy : nil) { compactSort = compactSort.tapped(column) }
                    }
                case .tableRow(let item, let last):
                    V2LibraryListRow(item: item, last: last)
                }
            }
        }
        .scrollTargetLayout()
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(Theme.mut)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .v2CardStyle(padding: 16)
    }

    /// The kind in view, as a plural noun ("series", "movies", "titles").
    private var noun: String {
        LibraryKind(rawValue: filters.kind)?.plural.lowercased() ?? "titles"
    }

    /// The library's titles of that kind, before any filter or words.
    private var kindTotal: Int {
        guard let kind = LibraryKind(rawValue: filters.kind) else { return model.library.count }
        return model.library.reduce(0) { $0 + ($1.libraryKind == kind ? 1 : 0) }
    }
}
