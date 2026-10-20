import SwiftUI
import FusionhaKit

// MARK: - Status cluster (TopBar `statusCluster`, ruling S3)
//
// Past 720 of a tab's own width the web's top bar shows a status cluster:
// live Activity, Needs attention and the backend light. iOS keeps its glass
// tab bar (a recorded deviation) and puts the cluster in the system bar as
// three standard items (title + symbol, counts as badges), so iOS can still
// move them into a vertical bar. Each opens the web's dropdown as a popover.

/// The cluster's live figures: the stats feed (operations, attention rows) and
/// `/health`, refreshed at most every few seconds while a cluster is on screen.
@MainActor
@Observable
final class ShellStatusFeed {
    static let shared = ShellStatusFeed()

    private(set) var connection: ConnectionLine = .connecting
    @ObservationIgnored private var lastRefresh = Date.distantPast

    var activeCount: Int { StatsSheetFeed.shared.inProgress.filter(\.active).count }

    func refresh(_ model: AppModel) async {
        guard Date().timeIntervalSince(lastRefresh) > 4, let client = model.client else { return }
        lastRefresh = Date()
        do {
            let health = try await client.health()
            connection = ConnectionLine(loading: false, failed: false, status: health.status)
        } catch is CancellationError {
            return
        } catch {
            connection = .offline
        }
        await StatsSheetFeed.shared.load(client: client, queue: model.queue)
    }
}

/// Which of the cluster's popovers is open.
enum StatusClusterPanel: Hashable {
    case activity, attention, health
}

/// The three items, trailing, before Account. Only for wide panes and users
/// who manage the server (`StatusClusterRule`).
struct StatusClusterItems: ToolbarContent {
    let model: AppModel
    let shown: Bool
    @Binding var open: StatusClusterPanel?

    private var feed: ShellStatusFeed { .shared }

    var body: some ToolbarContent {
        if shown {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { open = .activity } label: {
                    Label("Activity", systemImage: feed.activeCount > 0 ? "arrow.triangle.2.circlepath" : "waveform.path.ecg")
                }
                .badge(feed.activeCount)
                .accessibilityLabel(feed.activeCount > 0 ? "Activity, \(feed.activeCount) in progress" : "Activity")
                .popover(isPresented: binding(.activity)) { StatusActivityPanel(close: close) }
                Button { open = .attention } label: {
                    Label("Needs attention", systemImage: "exclamationmark.triangle")
                }
                .badge(model.attentionCount)
                .popover(isPresented: binding(.attention)) { StatusAttentionPanel(close: close) }
                Button { open = .health } label: {
                    Label("Backend", systemImage: healthSymbol)
                }
                .accessibilityValue(feed.connection.label)
                .popover(isPresented: binding(.health)) { StatusHealthPanel(connection: feed.connection) }
            }
            .barPriority(false)
        }
    }

    private var healthSymbol: String {
        switch feed.connection {
        case .ok: return "checkmark.icloud"
        case .offline: return "icloud.slash"
        case .connecting, .unknown: return "icloud"
        }
    }

    private func close() { open = nil }

    private func binding(_ panel: StatusClusterPanel) -> Binding<Bool> {
        Binding(get: { open == panel }, set: { if !$0 && open == panel { open = nil } })
    }
}

/// A popover panel's frame: the title, the body, the web's dropdown width.
private struct StatusPanelFrame<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.txt)
                content
            }
            .padding(18)
        }
        .frame(idealWidth: 380, maxHeight: 520)
        .presentationCompactAdaptation(.popover)
        .presentationBackground(Theme.panel)
    }
}

/// OperationsPanel: what is running, and the way to all of it.
private struct StatusActivityPanel: View {
    @Environment(AppModel.self) private var model
    let close: () -> Void

    var body: some View {
        StatusPanelFrame(title: "Activity") {
            StatsInProgressList(operations: StatsSheetFeed.shared.inProgress) { _ in
                close()
                model.tab = .activity
            }
            Button {
                close()
                model.pendingActivityTab = .tasks
                model.tab = .activity
            } label: {
                Text("View all activity ›")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.grab)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
            }
            .buttonStyle(.plain)
            .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        }
    }
}

/// AttentionControl: the same rows as the stats sheet's Needs attention.
private struct StatusAttentionPanel: View {
    @Environment(AppModel.self) private var model
    let close: () -> Void

    var body: some View {
        let feed = StatsSheetFeed.shared
        StatusPanelFrame(title: "Needs attention") {
            StatsAttentionList(indexers: feed.indexers, rows: feed.rows, manageIndexers: {
                close()
                Task { @MainActor in
                    // Let the popover go before the Settings cover comes up.
                    try? await Task.sleep(for: .milliseconds(350))
                    model.avatar.settingsPanel = "indexers"
                    model.avatar.showingSettings = true
                }
            }, openRow: { row in
                close()
                model.statsOpenRow(row)
            }, act: { row in
                close()
                model.statsAct(row)
            }, dismissRow: { model.statsDismiss($0, feed: feed) })
            .padding(.horizontal, -18)
        }
    }
}

/// HealthBadge: the backend light and its words.
private struct StatusHealthPanel: View {
    let connection: ConnectionLine

    var body: some View {
        let dot: Color = connection == .ok ? Theme.done : connection == .offline ? Theme.danger : Theme.dim
        StatusPanelFrame(title: "Backend") {
            HStack(spacing: 8) {
                Circle().fill(dot).frame(width: 8, height: 8)
                Text(connection.label).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.mut)
            }
            .accessibilityElement(children: .combine)
        }
    }
}
