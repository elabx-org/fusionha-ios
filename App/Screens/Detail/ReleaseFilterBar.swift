import SwiftUI
import FusionhaKit

/// The Manual search filter state (the web's InteractiveSearch filters): title
/// keyword, resolution, protocol, indexer, sort and direction, and the hide
/// toggles. Reset per edition.
struct ReleaseFilters: Equatable {
    static let all = "__all__"

    var keyword = ""
    var resolution = Self.all
    var proto = Self.all
    var indexer = Self.all
    var sortKey: ReleaseSearch.SortKey = .score
    var ascending = false
    var hideRejected = true
    var hideBlocklisted = false

    /// The rows these filters keep, in their sort order.
    func apply(_ rows: [ReleasePreview]) -> [ReleasePreview] {
        let kw = keyword.trimmingCharacters(in: .whitespaces).lowercased()
        let kept = rows.filter { r in
            if hideRejected && r.rejected { return false }
            if hideBlocklisted && r.blocklisted == true { return false }
            if resolution != Self.all && ReleaseSearch.resolution(r.quality) != resolution { return false }
            if proto != Self.all && r.protocolName.uppercased() != proto { return false }
            if indexer != Self.all && ReleaseSearch.indexer(r) != indexer { return false }
            if !kw.isEmpty && !r.title.lowercased().contains(kw) { return false }
            return true
        }
        return ReleaseSearch.sorted(kept, by: sortKey, ascending: ascending)
    }
}

/// The horizontally scrolling filter row: title field, resolution / protocol /
/// indexer / sort menus, the direction button and the hide switches.
struct ReleaseFilterBar: View {
    let rows: [ReleasePreview]
    @Binding var filters: ReleaseFilters
    let reduce: Bool

    var body: some View {
        let resolutions = ordered(rows.map { ReleaseSearch.resolution($0.quality) })
        let indexers = ordered(rows.map(ReleaseSearch.indexer))
        let mixed = rows.contains(where: ReleaseSearch.isTorrent) && rows.contains(where: ReleaseSearch.isUsenet)
        let keys = ReleaseSearch.SortKey.allCases.filter { !$0.torrentOnly || rows.contains(where: ReleaseSearch.isTorrent) }
        let rejectedCount = rows.filter(\.rejected).count
        let blocklistedCount = rows.filter { $0.blocklisted == true }.count
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                TextField("Filter by title…", text: $filters.keyword)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.txt)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .padding(.horizontal, 12)
                    .frame(width: 180, height: 38)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.line))
                    .accessibilityLabel("Filter by title")
                SearchFilterMenu(label: filters.resolution == ReleaseFilters.all ? "All resolutions" : filters.resolution,
                                 accessibility: "Resolution") {
                    Picker("Resolution", selection: $filters.resolution) {
                        Text("All resolutions").tag(ReleaseFilters.all)
                        ForEach(resolutions, id: \.self) { Text($0).tag($0) }
                    }
                }
                if mixed {
                    SearchFilterMenu(label: filters.proto == ReleaseFilters.all ? "All protocols"
                                         : ReleaseSearch.protocolLabel(filters.proto),
                                     accessibility: "Protocol") {
                        Picker("Protocol", selection: $filters.proto) {
                            Text("All protocols").tag(ReleaseFilters.all)
                            Text("Usenet").tag("USENET")
                            Text("Torrent").tag("TORRENT")
                        }
                    }
                }
                if indexers.count > 1 {
                    SearchFilterMenu(label: filters.indexer == ReleaseFilters.all ? "All indexers" : filters.indexer,
                                     accessibility: "Indexer") {
                        Picker("Indexer", selection: $filters.indexer) {
                            Text("All indexers").tag(ReleaseFilters.all)
                            ForEach(indexers, id: \.self) { Text($0).tag($0) }
                        }
                    }
                }
                SearchFilterMenu(label: filters.sortKey.label, prefix: "Sort:", accessibility: "Sort") {
                    Picker("Sort", selection: Binding(get: { filters.sortKey }, set: { pick in
                        guard pick != filters.sortKey else { return }
                        filters.sortKey = pick
                        filters.ascending = pick.initialAscending
                    })) {
                        ForEach(keys, id: \.self) { Text($0.label).tag($0) }
                    }
                }
                Button { filters.ascending.toggle() } label: {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.mut)
                        .rotationEffect(.degrees(filters.ascending ? 180 : 0))
                        .animation(reduce ? nil : .easeInOut(duration: 0.2), value: filters.ascending)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Sort direction: \(filters.ascending ? "ascending" : "descending"). Tap to reverse.")
                .help(filters.ascending ? "Ascending — tap for descending" : "Descending — tap for ascending")
                HStack(spacing: 16) {
                    Toggle(isOn: $filters.hideRejected) {
                        Text(rejectedCount > 0 ? "Hide rejected (\(rejectedCount))" : "Hide rejected")
                    }
                    .accessibilityLabel("Hide rejected releases")
                    if blocklistedCount > 0 {
                        Toggle(isOn: $filters.hideBlocklisted) { Text("Hide blocklisted (\(blocklistedCount))") }
                            .accessibilityLabel("Hide blocklisted releases")
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(Theme.indigo)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.mut)
                .fixedSize()
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
        .padding(.bottom, 12)
    }

    private func ordered(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
