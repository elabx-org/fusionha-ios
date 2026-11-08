import SwiftUI
import FusionhaKit

/// The Indexers list (mock settings-ix.js, phone): the page header, Test
/// all · Add, the fleet card, every indexer grouped by priority, coverage
/// and budget, then the fetching helpers (v1's FlareSolverr and list-site
/// cards).
struct V2IndexerListColumn: View {
    let model: V2IndexersModel
    let rows: [IndexerMetric]
    let sortLabel: String
    var selected: Int?
    /// Beside the detail on the open Duo: chevrons, and a shorter legend.
    var beside = false
    @Binding var range: IndexerRange
    @Binding var headerGone: Bool
    let colorFor: (Int) -> Color
    let open: (Int) -> Void
    let onAdd: () -> Void
    @Environment(AppModel.self) private var appModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                V2SettingsPageHeader(slug: "indexers")
                    .settingsReveal()
                actions.padding(.top, 14)
                if model.statsLoaded {
                    V2IndexerFleetCard(summary: model.stats?.summary, metrics: model.metrics, range: $range,
                                       legendCount: beside ? 3 : 5, colorFor: colorFor,
                                       onTest: { model.test($0, client: appModel.client) })
                        .padding(.top, 12)
                        .settingsReveal(delay: 0.06)
                }
                if !model.loaded || model.error != nil {
                    FetchLoading(error: model.error).padding(.top, 8)
                }
                if model.loaded, model.indexers.isEmpty, model.error == nil {
                    FetchEmpty(text: "No indexers yet. Add a Newznab or Torznab indexer, or let Prowlarr sync them in.")
                        .padding(.top, 16)
                }
                V2IndexerGroups(rows: rows, sortLabel: sortLabel, colorFor: colorFor, model: model,
                                selected: selected, chevrons: beside, roomy: !beside,
                                open: open,
                                onToggle: { model.toggle($0, $1, client: appModel.client) })
                if let summary = model.stats?.summary {
                    V2IndexerCoverageCard(summary: summary)
                }
                V2SettingsGroupHeader(title: "Fetching help")
                FlareSolverrCard()
                ListSitesCard().padding(.top, 12)
            }
            .padding(.horizontal, Theme.pageGutter)
            .padding(.top, 6)
            .padding(.bottom, 64)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .v2SettingsHeaderWatch($headerGone)
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await model.load(appModel.client) }
    }

    /// Test all · Add (mock `actions`). Prowlarr sync has no API to call,
    /// so it isn't offered (docs/v2.md).
    private var actions: some View {
        HStack(spacing: 8) {
            Button { model.testAll(client: appModel.client) } label: {
                Label(model.testingAll ? "Testing…" : "Test all", systemImage: "bolt")
                    .frame(maxWidth: .infinity)
                    .frame(height: 24)
            }
            .buttonStyle(.glass)
            .disabled(model.indexers.isEmpty || model.testingAll)
            Button(action: onAdd) {
                Label("Add", systemImage: "plus")
                    .foregroundStyle(Theme.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 24)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.primary)
            .accessibilityLabel("Add indexer")
        }
        .font(.subheadline.weight(.semibold))
        .buttonBorderShape(.capsule)
    }
}
