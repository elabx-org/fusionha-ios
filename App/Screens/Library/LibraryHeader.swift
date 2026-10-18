import SwiftUI
import FusionhaKit

/// The Library page header (redesign): the display title with the glass
/// "Library stats" button, then a two-line caption. Line one counts titles and
/// versions; line two is live state, where "need attention" toggles the
/// attention filter (the web's toolbar pill) and "downloading" opens Activity.
struct LibraryHeader: View {
    let derived: LibraryDerived
    @Binding var status: LibraryStatus
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
            ShellTitleRow("Library") {
                AddTitleButton()
                GlassIconButton(systemName: "chart.bar.xaxis", label: "Library stats",
                                dot: needsAttention ? Theme.miss : nil) { showingStats = true }
            }
            caption
            LibraryFilterField().padding(.top, 4)
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

    private var needsAttention: Bool {
        (derived.pulse.titleCounts[.missing] ?? 0) > 0 || downloading > 0 || attention > 0
    }

    private var caption: some View {
        let t = derived.titleCount, e = derived.editionCount
        return VStack(alignment: .leading, spacing: 2) {
            (Text("\(t)").fontWeight(.semibold).foregroundColor(Theme.txt)
             + Text(" \(t == 1 ? "title" : "titles") · \(e) \(e == 1 ? "version" : "versions")"))
                .contentTransition(.numericText())
            if downloading > 0 || attention > 0 || status == .attention {
                HStack(spacing: 0) {
                    if downloading > 0 {
                        Button { model.tab = .activity } label: {
                            Text("\(downloading) downloading").fontWeight(.semibold).foregroundStyle(Theme.grab)
                        }
                        .buttonStyle(.plain)
                    }
                    if downloading > 0 && (attention > 0 || status == .attention) { Text(" · ") }
                    if attention > 0 || status == .attention { attentionToggle }
                }
            }
        }
        .font(.system(size: 15).monospacedDigit())
        .foregroundStyle(Theme.mut)
    }

    private var attentionToggle: some View {
        let on = status == .attention
        return Button {
            withAnimation(motion ? .snappy : nil) { status = on ? .all : .attention }
        } label: {
            HStack(spacing: 4) {
                Text("\(attention) need\(attention == 1 ? "s" : "") attention").fontWeight(.semibold)
                if on { Image(systemName: "xmark.circle.fill").font(.system(size: 13)) }
            }
            .foregroundStyle(Theme.miss)
            .underline(on)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(on ? "Showing titles that need attention. Show all" : "Show titles that need attention")
    }
}
