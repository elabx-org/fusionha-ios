import SwiftUI
import FusionhaKit

/// The Library's filter row, F1 (mock filters-alt.js, the recommended
/// option): the All | HD | 4K segmented control and one glass Filter menu
/// with a count. The filters it sets show under it as removable tokens, and
/// only when something is set (`V2LibraryFilterTokens`).
struct V2LibraryFilterRow: View {
    let filters: V2LibraryFilters
    /// Titles needing attention in the current set (the menu's count).
    let attentionCount: Int

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                // filters-alt.js `vers()`: a fixed 150pt control.
                SegmentedPills(options: [(LibraryTier.all, "All"), (.hd, "HD"), (.uhd, "4K")],
                               selection: filters.$tier, fill: true)
                    .frame(width: 150)
                V2LibraryFilterMenu(filters: filters, attentionCount: attentionCount)
                Spacer(minLength: 0)
            }
        }
    }
}

/// F1's one Filter menu: Show (the status filter), Sort and Display as
/// pickers, then "More filters" (recency, group by status, combine HD + 4K)
/// and Reset. Native menu, glass label.
struct V2LibraryFilterMenu: View {
    let filters: V2LibraryFilters
    let attentionCount: Int
    @Environment(AppModel.self) private var model

    private var count: Int { filters.tokens.count }

    var body: some View {
        Menu {
            Section("Show") {
                ForEach(LibraryStatus.v2MenuOrder, id: \.self) { status in
                    Toggle(isOn: showing(status)) {
                        Label(label(for: status), systemImage: status.v2Symbol)
                    }
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
            Button("Reset filters", systemImage: "arrow.uturn.backward") { filters.reset() }
                .disabled(count == 0 && filters.sort == .title)
        } label: {
            menuLabel
        }
        .glassControl(on: count > 0)
        .fixedSize()
        .accessibilityLabel("Filter")
        .accessibilityValue(count > 0 ? "\(count) on" : "")
    }

    private var menuLabel: some View {
        // kit `.chip` (34 high, 13.5pt, 15pt icon) and `.bdg` (18, 11 bold).
        HStack(spacing: 7) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 15, weight: .semibold))
            Text("Filter").font(.system(size: 13.5, weight: .semibold))
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 5)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Theme.primary, in: Capsule())
            }
        }
        .foregroundStyle(Theme.txt)
        .padding(.horizontal, 13)
        .frame(height: 34)
        .contentShape(Capsule())
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
