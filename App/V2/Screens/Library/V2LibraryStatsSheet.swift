import SwiftUI
import FusionhaKit

/// v2's Library stats page (mock browse-lib.js `statsBody`): "Library" with
/// a Settings gear, the connection line with the server version, then W1
/// modules on the tint ground: five status pills (each sets the grid's
/// status filter), the health / 4K coverage / on-disk meters, In progress,
/// Needs attention (Replace / Manage / Review) and "View all activity". The
/// same live sources as v1's sheet (`StatsSheetFeed`). Swipe down or Escape
/// closes it. Open Duo: the modules sit in two columns.
struct V2LibraryStatsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.motionEnabled) private var motion
    let pulse: PulseStats
    let numbers: V2LibraryNumbers
    @Binding var status: LibraryStatus
    /// Close the sheet, then open Settings › Indexers.
    var manageIndexers: () -> Void = {}
    /// Close the sheet, then open Settings.
    var openSettings: () -> Void = {}
    @State private var grown = false
    @State private var feed = StatsSheetFeed.shared
    @State private var connection: ConnectionLine = .connecting
    @State private var version: String?
    @State private var width: CGFloat = 0

    private var twoColumns: Bool { width >= 700 }
    private var attentionCount: Int { feed.rows.count + feed.indexers.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if twoColumns {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(spacing: 14) {
                            statusModule
                            coverageModule
                        }
                        VStack(spacing: 14) {
                            progressModule
                            attentionModule
                        }
                    }
                } else {
                    statusModule
                    coverageModule
                    progressModule
                    attentionModule
                }
                activityLink
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .v2PageGround(art: nil)
        .onAppear { withAnimation(motion ? Motion.reveal(1.1) : nil) { grown = true } }
        .task { await checkHealth() }
        .task {
            while !Task.isCancelled {
                if let client = model.client { await feed.load(client: client, queue: model.queue) }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Text("Library").font(.title2.weight(.bold)).foregroundStyle(Theme.txt)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                GlassIconButton(systemName: "gearshape", label: "Settings", size: 34) {
                    openSettings()
                    dismiss()
                }
            }
            V2ConnectionLine(connection: connection, version: version)
                .padding(.horizontal, 4)
        }
        // No close button: swipe down, or Escape on a keyboard.
        .background {
            Button("Close") { dismiss() }
                .closeOnEscape()
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }

    /// The mock's five pills, each dot in its status colour.
    private var pills: [(LibraryStatus, String, Color)] {
        [(.complete, "Complete", Theme.done), (.missing, "Missing", Theme.miss),
         (.upcoming, "Upcoming", Theme.unaired), (.downloading, "Downloading", Theme.grab),
         (.attention, "Attention", Theme.stuck)]
    }

    private func count(_ key: LibraryStatus) -> Int {
        if key == .attention { return numbers.attention }
        return CardStatus(rawValue: key.rawValue).flatMap { pulse.titleCounts[$0] } ?? 0
    }

    private var statusModule: some View {
        WidgetModule(caption: "Titles") {
            // browse.css `.spill { flex: 1 1 28% }`: three to a row.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(pills, id: \.0) { entry in
                    V2StatPill(key: entry.0, label: entry.1, count: count(entry.0), color: entry.2,
                               status: $status) { dismiss() }
                }
            }
        }
    }

    private var coverageModule: some View {
        WidgetModule(caption: "Coverage") {
            V2StatsMeters(numbers: numbers, grown: grown)
        }
    }

    private var progressModule: some View {
        WidgetModule(caption: "In progress") {
            StatsInProgressList(operations: feed.inProgress) { _ in
                dismiss()
                model.tab = .activity
            }
        }
    }

    private var attentionModule: some View {
        WidgetModule(caption: attentionCount > 0 ? "Needs attention · \(attentionCount)" : "Needs attention",
                     needsYou: attentionCount > 0) {
            StatsAttentionList(indexers: feed.indexers, rows: feed.rows, incomplete: feed.incomplete,
                               manageIndexers: {
                manageIndexers()
                dismiss()
            }, openRow: { row in
                dismiss()
                model.statsOpenRow(row)
            }, act: { row in
                dismiss()
                model.statsAct(row)
            }, dismissRow: { model.statsDismiss($0, feed: feed) })
            .padding(.horizontal, -16)
        }
    }

    private var activityLink: some View {
        Button {
            dismiss()
            model.pendingActivityTab = .tasks
            model.tab = .activity
        } label: {
            HStack {
                Spacer(minLength: 0)
                Text("View all activity ›")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accentText)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func checkHealth() async {
        guard let client = model.client else { connection = .unknown; return }
        do {
            let health = try await client.health()
            connection = ConnectionLine(loading: false, failed: false, status: health.status)
            version = health.version.isEmpty ? nil : health.version
        } catch is CancellationError {
            return
        } catch {
            connection = .offline
        }
    }
}
