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
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    @State private var showingStats = false
    /// "Manage" on the unavailable-indexers row: Settings › Indexers opens once the sheet is gone.
    @State private var pendingIndexerSettings = false
    @State private var showingIndexerSettings = false
    @State private var statsDetent: PresentationDetent = .medium

    private var downloading: Int { derived.pulse.titleCounts[.downloading] ?? 0 }
    private var attention: Int { derived.attentionCount }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            caption
            if searching || !model.searchText.isEmpty {
                // The iPhone Duo's fold through the header (Web layout): the field
                // ends at the gutter instead of running across it.
                LibraryFilterField(shown: $searching)
                    .foldLeadingPane()
                    .transition(motion ? .opacity.combined(with: .offset(y: -8)) : .opacity)
            }
        }
        .animation(motion ? .spring(duration: 0.35, bounce: 0) : .easeInOut(duration: 0.2), value: searching)
        .toolbar {
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
}
