import SwiftUI
import FusionhaKit

/// The Library's Filter item in the bar (v2 header, mock home 'live': the
/// page keeps only the chip row): Show, Sort, Display, More filters, Select
/// and Reset as one native menu, badged with the number of filters set.
struct V2LibraryFilterMenu: View {
    let filters: V2LibraryFilters
    /// Titles needing attention in the current set (Show's count).
    let attentionCount: Int

    private var count: Int { filters.tokens.count }

    var body: some View {
        Menu {
            V2LibraryFilterMenuItems(filters: filters, attentionCount: attentionCount)
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease")
        }
        .badge(count)
        .accessibilityLabel("Filter")
        .accessibilityValue(count > 0 ? "\(count) on" : "")
    }
}

/// The Filter menu's items (F1, filters-alt.js): Show (the status filter,
/// and Not monitored), Sort and Display as pickers, then "More filters"
/// (recency, group by status, combine HD + 4K), Select and Reset. Also a
/// submenu of More on a Spread's narrow left page.
struct V2LibraryFilterMenuItems: View {
    let filters: V2LibraryFilters
    let attentionCount: Int
    /// Select mode from here (the bar's own Select left with the v2 header).
    var includesSelect = true
    @Environment(AppModel.self) private var model

    var body: some View {
        Section("Show") {
            ForEach(LibraryStatus.v2MenuOrder, id: \.self) { status in
                Toggle(isOn: showing(status)) {
                    Label(label(for: status), systemImage: status.v2Symbol)
                }
            }
            Toggle(isOn: filters.$unmonitored) {
                Label("Not monitored", systemImage: "bookmark.slash")
            }
        }
        Picker(selection: filters.$sort) {
            ForEach(LibrarySort.allCases) { Text($0.label).tag($0) }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
        .pickerStyle(.menu)
        Picker(selection: filters.$density) {
            Label("Posters", systemImage: "square.grid.3x2").tag("grid")
            Label("List", systemImage: "list.bullet").tag("compact")
        } label: {
            Label("Display", systemImage: "square.grid.2x2")
        }
        .pickerStyle(.menu)
        Section("More filters") {
            Picker(selection: filters.$recency) {
                Text("Any time").tag(LibraryRecency.all)
                Text("Added in the last 30 days").tag(LibraryRecency.added)
                Text("Released in the last 30 days").tag(LibraryRecency.released)
            } label: {
                Label("Recency", systemImage: "clock")
            }
            .pickerStyle(.menu)
            Toggle(isOn: filters.$group) {
                Label("Group by status", systemImage: "list.bullet.indent")
            }
            if model.me?.isAdmin == true {
                Toggle(isOn: combine) {
                    Label("Combine HD + 4K", systemImage: "arrow.triangle.merge")
                }
            }
        }
        Divider()
        if includesSelect && !model.selectMode {
            Button("Select", systemImage: "checkmark.circle") { model.selectMode = true }
        }
        Button("Reset filters", systemImage: "arrow.uturn.backward") { filters.reset() }
            .disabled(filters.tokens.isEmpty && filters.sort == .title)
    }

    private func label(for status: LibraryStatus) -> String {
        status == .attention && attentionCount > 0 ? "Needs attention · \(attentionCount)" : status.v2Label
    }

    /// One Show item: on while it is the status filter; turning it off clears it.
    private func showing(_ status: LibraryStatus) -> Binding<Bool> {
        Binding(get: { filters.status == status },
                set: { filters.status = $0 ? status : .all })
    }

    /// The server's Combine HD + 4K setting (admins only, saved for everyone).
    private var combine: Binding<Bool> {
        Binding(get: { model.railConsolidate },
                set: { value in Task { await model.updateRails(consolidate: value) } })
    }
}
