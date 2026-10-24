import SwiftUI
import FusionhaKit

/// The Library page header (owner-approved layout A): Search, Select, "Library
/// stats" and Add as toolbar items (D1; the large title is the system bar's),
/// then one line, "14 titles · 19 versions · 4 downloading", the last in the
/// grab colour and linked to Activity. Search opens the library filter under
/// the line on demand (it left the page at rest). The needs-attention filter
/// is the control row's chip, as on the web.
struct LibraryHeader: View {
    let derived: LibraryDerived
    @Binding var status: LibraryStatus
    /// The filter field is open (Search in the bar, or words still in it).
    @Binding var searching: Bool
    /// Past 720 the pulse is inline and the status cluster holds In progress
    /// and Needs attention, so the stats item goes (as on the web's desktop).
    var wide = false
    /// The kind control is showing labels only: the per-kind counts go here.
    var kindCounts = false
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    @Environment(\.spread) private var spread
    @State private var showingStats = false
    /// "Manage" on the unavailable-indexers row: Settings › Indexers opens once the sheet is gone.
    @State private var pendingIndexerSettings = false
    @State private var showingIndexerSettings = false
    @State private var statsDetent: PresentationDetent = .medium

    private var downloading: Int { derived.pulse.titleCounts[.downloading] ?? 0 }
    private var attention: Int { derived.attentionCount }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                caption
                if kindCounts { kindLine }
            }
            if searching || !model.searchText.isEmpty {
                // The iPhone Duo's fold through the header (Web layout): the field
                // ends at the gutter instead of running across it.
                LibraryFilterField(shown: $searching)
                    .foldLeadingColumn()
                    .transition(motion ? .opacity.combined(with: .offset(y: -8)) : .opacity)
            }
        }
        .animation(motion ? .spring(duration: 0.35, bounce: 0) : .easeInOut(duration: 0.2), value: searching)
        .toolbar {
            if overflowBar {
                // A Spread's left page with a title open: Spread, Account and
                // Search stay; Select, Library stats and Add share one menu, so
                // the title never truncates (six glass buttons squeezed it to
                // "Lib…" though Select and Stats had low visibility priority).
                if !model.selectMode {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Search", systemImage: "magnifyingglass") { searching = true }
                    }
                    .barPriority(true)
                    ToolbarItem(placement: .topBarTrailing) { overflowMenu.badge(statsBadge) }
                        .barPriority(false)
                }
            } else {
                if !model.selectMode {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Search", systemImage: "magnifyingglass") { searching = true }
                    }
                    .barPriority(true)
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Select", systemImage: "checkmark.circle") { model.selectMode = true }
                    }
                    .barPriority(false)
                }
                AddTitleToolbarItem(model: model)
                if !wide {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Library stats", systemImage: "chart.bar.xaxis") { showingStats = true }
                            .badge(statsBadge)
                    }
                    .barPriority(false)
                }
            }
        }
        // Warm the stats sheet's In progress / Needs attention, so it opens filled.
        .task {
            if let client = model.client { await StatsSheetFeed.shared.load(client: client, queue: model.queue) }
        }
        .sheet(isPresented: $showingStats, onDismiss: {
            if pendingIndexerSettings {
                pendingIndexerSettings = false
                showingIndexerSettings = true
            }
        }) {
            LibraryStatsSheet(pulse: derived.pulse, status: $status) { pendingIndexerSettings = true }
                .presentationDetents([.medium, .large], selection: $statsDetent)
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.panel)
        }
        #if DEBUG
        .task {
            // CI screenshots: `FUSIONHA_SCREENSHOT_STATS=1|attention` opens the stats sheet full height.
            guard ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_STATS"] != nil else { return }
            try? await Task.sleep(for: .seconds(1.5))
            statsDetent = .large
            showingStats = true
        }
        #endif
        .fullScreenCover(isPresented: $showingIndexerSettings) {
            SettingsView(client: model.client, initialPanel: "indexers")
        }
    }

    /// The bar is a Spread's left page beside an open title: too narrow for
    /// the title and six items.
    private var overflowBar: Bool { spread.isActive && !spread.spans }

    private var canAdd: Bool { !model.requestScoped && model.me?.can("add") != false }

    /// Select, Library stats and Add in one bar item (the overflow bar).
    private var overflowMenu: some View {
        Menu {
            Button("Select", systemImage: "checkmark.circle") { model.selectMode = true }
            Button("Library stats", systemImage: "chart.bar.xaxis") { showingStats = true }
            if canAdd {
                Button("Add", systemImage: "plus") { model.showingAdd = true }
            }
        } label: {
            Label("More", systemImage: "ellipsis")
        }
        .accessibilityLabel(statsBadge == nil ? "More" : "More, library needs attention")
    }

    /// The stats item's badge: titles needing attention, else missing ones
    /// (a count, as the HIG asks of bar items, in place of the old dot).
    private var statsBadge: Text? {
        let missing = derived.pulse.titleCounts[.missing] ?? 0
        let n = attention > 0 ? attention : missing
        return BadgeCount.text(n).map { Text(verbatim: $0) }
    }

    private var caption: some View {
        let t = derived.titleCount, e = derived.editionCount
        return HStack(spacing: 0) {
            (Text("\(t)").fontWeight(.semibold).foregroundColor(Theme.txt)
             + Text(" \(t == 1 ? "title" : "titles") · \(e) \(e == 1 ? "version" : "versions")"))
                .contentTransition(.numericText())
            if downloading > 0 {
                Text(" · ")
                Button { model.tab = .activity } label: {
                    Text("\(downloading) downloading").foregroundStyle(Theme.grab)
                }
                .buttonStyle(.plain)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .font(.system(size: 15).monospacedDigit())
        .foregroundStyle(Theme.mut)
    }

    /// "2,629 movies · 734 series · 37 anime · 385 animation": the kind
    /// control's counts when it has no room for them. Wraps, never truncates.
    private var kindLine: some View {
        let kinds = KindControl.kinds(titles: derived.kindTitles, active: nil)
        let parts = kinds.map { k -> String in
            let n = derived.kindTitles[k] ?? 0
            return "\(n.formatted()) \(k.plural.lowercased())"
        }
        return Text(parts.joined(separator: " · "))
            .font(.system(size: 13).monospacedDigit())
            .foregroundStyle(Theme.mut)
            .fixedSize(horizontal: false, vertical: true)
            .contentTransition(.numericText())
    }
}
