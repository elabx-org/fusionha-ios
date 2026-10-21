import SwiftUI
import FusionhaKit

/// The Library page header: Add and "Library stats" as toolbar items (D1; the
/// title is the system bar's), then a two-line caption. Line one counts titles and
/// versions; line two (an iOS extra) links "N downloading" to Activity. The
/// needs-attention filter is the toolbar's chip, as on the web.
struct LibraryHeader: View {
    let derived: LibraryDerived
    @Binding var status: LibraryStatus
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
        VStack(alignment: .leading, spacing: 8) {
            caption
            // The iPhone Duo's fold through the header (Web layout): the field
            // ends at the gutter instead of running across it.
            LibraryFilterField().foldLeadingPane().padding(.top, 4)
        }
        .toolbar {
            AddTitleToolbarItem(model: model)
            if !wide {
                ToolbarItem(placement: .secondaryAction) {
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
        return VStack(alignment: .leading, spacing: 2) {
            (Text("\(t)").fontWeight(.semibold).foregroundColor(Theme.txt)
             + Text(" \(t == 1 ? "title" : "titles") · \(e) \(e == 1 ? "version" : "versions")"))
                .contentTransition(.numericText())
            if downloading > 0 {
                Button { model.tab = .activity } label: {
                    Text("\(downloading) downloading").fontWeight(.semibold).foregroundStyle(Theme.grab)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.system(size: 15).monospacedDigit())
        .foregroundStyle(Theme.mut)
    }
}
