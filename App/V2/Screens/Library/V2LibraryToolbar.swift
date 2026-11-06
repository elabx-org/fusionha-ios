import SwiftUI
import FusionhaKit

/// The v2 Library's bar items (mock browse-lib.js, v2 header): Add, Filter
/// (Show, Sort, Display, More filters, Select, Reset; badged with the filters
/// set) and Library stats (badged when something needs attention), and the
/// stats page they open. The library filter is the pull-down search field
/// (`V2LibrarySearch`). The folded Duo's column leads with Account, then the
/// prominent Add, Filter and one More menu; a Spread's left page beside a
/// title folds Filter, Select, stats and Add into one menu.
struct V2LibraryToolbar: ViewModifier {
    let derived: LibraryDerived
    let filters: V2LibraryFilters
    @Environment(AppModel.self) private var model
    @Environment(\.spread) private var spread
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showingStats = false
    /// Settings to open once the stats sheet has closed, and at which panel.
    @State private var pendingSettings = false
    @State private var settingsPanel: String?
    @State private var showingSettings = false

    private var foldedDuo: Bool { OuterDisplay.isFoldedDuo(sizeClass: sizeClass) }
    private var overflowBar: Bool { spread.isActive && !spread.spans }
    private var canAdd: Bool { !model.requestScoped && model.me?.can("add") != false }

    func body(content: Content) -> some View {
        content
            .toolbar { items }
            .task {
                if let client = model.client { await StatsSheetFeed.shared.load(client: client, queue: model.queue) }
            }
            .sheet(isPresented: $showingStats, onDismiss: {
                if pendingSettings {
                    pendingSettings = false
                    showingSettings = true
                }
            }) {
                V2LibraryStatsSheet(pulse: derived.pulse, numbers: numbers, status: filters.$status, manageIndexers: {
                    settingsPanel = "indexers"
                    pendingSettings = true
                }, openSettings: {
                    settingsPanel = nil
                    pendingSettings = true
                })
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Theme.bg)
            }
            .fullScreenCover(isPresented: $showingSettings) {
                AppSettingsView(client: model.client, initialPanel: settingsPanel)
            }
    }

    @ToolbarContentBuilder
    private var items: some ToolbarContent {
        if foldedDuo {
            AccountToolbarItem(model: model)
            if canAdd && !model.selectMode {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add", systemImage: "plus") { model.showingAdd = true }
                        .buttonStyle(.glassProminent)
                        .tint(Theme.indigo)
                }
                .barPriority(true)
            }
            filterItem
            if !model.selectMode {
                ToolbarItem(placement: .topBarTrailing) { moreMenu(compact: false).badge(statsBadge) }
                    .barPriority(true)
            }
        } else if overflowBar {
            if model.selectMode {
                filterItem
            } else {
                ToolbarItem(placement: .topBarTrailing) { moreMenu(compact: true).badge(statsBadge) }
                    .barPriority(false)
            }
        } else {
            AddTitleToolbarItem(model: model)
            filterItem
            if !model.selectMode {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Library stats", systemImage: "chart.bar.xaxis") { showingStats = true }
                        .badge(statsBadge)
                }
                .barPriority(true)
            }
        }
    }

    /// Filter (Sort and Select inside it) on every bar; select mode keeps it.
    private var filterItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            V2LibraryFilterMenu(filters: filters, attentionCount: derived.attentionCount)
        }
        .barPriority(true)
    }

    /// Select and Library stats; on a Spread's narrow left page (`compact`)
    /// also Filter as a submenu, and Add.
    private func moreMenu(compact: Bool) -> some View {
        Menu {
            if compact {
                Menu {
                    V2LibraryFilterMenuItems(filters: filters, attentionCount: derived.attentionCount,
                                             includesSelect: false)
                } label: {
                    Label(filterTitle, systemImage: "line.3.horizontal.decrease")
                }
            }
            Button("Select", systemImage: "checkmark.circle") { model.selectMode = true }
            Button("Library stats", systemImage: "chart.bar.xaxis") { showingStats = true }
            if compact && canAdd {
                Button("Add", systemImage: "plus") { model.showingAdd = true }
            }
        } label: {
            Label("More", systemImage: "ellipsis")
        }
        .accessibilityLabel(statsBadge == nil ? "More" : "More, library needs attention")
    }

    /// "Filter", or "Filter · 2" with filters set.
    private var filterTitle: String {
        let n = filters.tokens.count
        return n == 0 ? "Filter" : "Filter · \(n)"
    }

    /// The stats page's numbers, from the titles the filters left.
    private var numbers: V2LibraryNumbers {
        let ids = Set(derived.visibleIds)
        return V2LibraryNumbers(model.library.filter { ids.contains($0.id) })
    }

    /// Titles needing attention, else missing ones (as v1's stats item).
    private var statsBadge: Text? {
        let missing = derived.pulse.titleCounts[.missing] ?? 0
        let n = derived.attentionCount > 0 ? derived.attentionCount : missing
        return BadgeCount.text(n).map { Text(verbatim: $0) }
    }
}
