import SwiftUI
import FusionhaKit

/// The release filters as one glass Menu (plan S6, mock `filters` state):
/// Sort (score, size, age, …) and its direction, Hide rejected, Hide
/// blocklisted, then Resolution, Indexer and Protocol, and Reset. The title
/// filter stays a field beside it. Same `ReleaseFilters` as v1's bar.
struct V2ReleaseFilterRow: View {
    let rows: [ReleasePreview]
    @Binding var filters: ReleaseFilters

    var body: some View {
        HStack(spacing: 8) {
            TextField("Filter by title", text: $filters.keyword)
                .font(.system(size: 15))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .glassEffect(.regular, in: Capsule())
                .accessibilityLabel("Filter by title")
            menu
        }
    }

    private var menu: some View {
        let resolutions = ordered(rows.map { ReleaseSearch.resolution($0.quality) })
        let indexers = ordered(rows.map(ReleaseSearch.indexer))
        let mixed = rows.contains(where: ReleaseSearch.isTorrent) && rows.contains(where: ReleaseSearch.isUsenet)
        let keys = ReleaseSearch.SortKey.allCases.filter { !$0.torrentOnly || rows.contains(where: ReleaseSearch.isTorrent) }
        let rejected = rows.filter(\.rejected).count
        let blocklisted = rows.filter { $0.blocklisted == true }.count
        return Menu {
            Section("Sort") {
                Picker("Sort by", selection: sortKey) {
                    ForEach(keys, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.inline)
                Button(filters.ascending ? "Ascending" : "Descending",
                       systemImage: filters.ascending ? "arrow.up" : "arrow.down") { filters.ascending.toggle() }
            }
            Section("Show") {
                Toggle(rejected > 0 ? "Hide rejected (\(rejected))" : "Hide rejected", isOn: $filters.hideRejected)
                if blocklisted > 0 {
                    Toggle("Hide blocklisted (\(blocklisted))", isOn: $filters.hideBlocklisted)
                }
            }
            Section {
                Picker("Resolution", selection: $filters.resolution) {
                    Text("Any").tag(ReleaseFilters.all)
                    ForEach(resolutions, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                if indexers.count > 1 {
                    Picker("Indexer", selection: $filters.indexer) {
                        Text("All \(indexers.count)").tag(ReleaseFilters.all)
                        ForEach(indexers, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
                if mixed {
                    Picker("Protocol", selection: $filters.proto) {
                        Text("Any").tag(ReleaseFilters.all)
                        Text("Usenet").tag("USENET")
                        Text("Torrent").tag("TORRENT")
                    }
                    .pickerStyle(.menu)
                }
            }
            if changes > 0 {
                Button("Reset filters", systemImage: "arrow.counterclockwise") {
                    let keyword = filters.keyword
                    filters = ReleaseFilters()
                    filters.keyword = keyword
                }
            }
        } label: {
            Label(changes > 0 ? "Filters · \(changes)" : "Filters", systemImage: "line.3.horizontal.decrease")
                .font(.system(size: 14, weight: .semibold))
                .frame(height: 22)
        }
        .buttonStyle(.glass)
        .fixedSize()
        .accessibilityLabel(changes > 0 ? "Filters, \(changes) changed" : "Filters")
    }

    /// Picking a new sort key also takes its natural direction (v1's rule).
    private var sortKey: Binding<ReleaseSearch.SortKey> {
        Binding(get: { filters.sortKey }, set: { pick in
            guard pick != filters.sortKey else { return }
            filters.sortKey = pick
            filters.ascending = pick.initialAscending
        })
    }

    /// How many filters differ from the defaults (the title filter aside).
    private var changes: Int {
        let base = ReleaseFilters()
        return [filters.sortKey != base.sortKey, filters.ascending != base.ascending,
                filters.hideRejected != base.hideRejected, filters.hideBlocklisted != base.hideBlocklisted,
                filters.resolution != base.resolution, filters.indexer != base.indexer, filters.proto != base.proto]
            .filter { $0 }.count
    }

    private func ordered(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
