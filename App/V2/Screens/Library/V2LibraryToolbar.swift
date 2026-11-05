import SwiftUI
import FusionhaKit

/// The v2 Library's bar items (mock browse-lib.js): Add, Select and Library
/// stats (badged when something needs attention), in the order v1's header
/// uses, and the stats page they open. The library filter is on the page,
/// so Search leaves the bar. The folded Duo's column leads with Account,
/// then the prominent Add, then one More menu; a Spread's left page beside a
/// title folds Select, stats and Add into one menu.
struct V2LibraryToolbar: ViewModifier {
    let derived: LibraryDerived
    @Binding var status: LibraryStatus
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
                V2LibraryStatsSheet(pulse: derived.pulse, numbers: numbers, status: $status, manageIndexers: {
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
                SettingsView(client: model.client, initialPanel: settingsPanel)
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
            if !model.selectMode {
                ToolbarItem(placement: .topBarTrailing) { moreMenu(withAdd: false).badge(statsBadge) }
                    .barPriority(true)
            }
        } else if overflowBar {
            if !model.selectMode {
                ToolbarItem(placement: .topBarTrailing) { moreMenu(withAdd: canAdd).badge(statsBadge) }
                    .barPriority(false)
            }
        } else {
            AddTitleToolbarItem(model: model)
            if !model.selectMode {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Select", systemImage: "checkmark.circle") { model.selectMode = true }
                }
                .barPriority(false)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Library stats", systemImage: "chart.bar.xaxis") { showingStats = true }
                        .badge(statsBadge)
                }
                .barPriority(true)
            }
        }
    }

    /// Select and Library stats (and Add, on a Spread's narrow left page).
    private func moreMenu(withAdd: Bool) -> some View {
        Menu {
            Button("Select", systemImage: "checkmark.circle") { model.selectMode = true }
            Button("Library stats", systemImage: "chart.bar.xaxis") { showingStats = true }
            if withAdd {
                Button("Add", systemImage: "plus") { model.showingAdd = true }
            }
        } label: {
            Label("More", systemImage: "ellipsis")
        }
        .accessibilityLabel(statsBadge == nil ? "More" : "More, library needs attention")
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
