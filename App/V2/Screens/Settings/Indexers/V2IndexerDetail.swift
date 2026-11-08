import SwiftUI
import FusionhaKit

/// One indexer (mock settings-ix.js `detail`): its tile, name, protocol and
/// priority with the switch; Test, Edit and Delete; four stats; activity;
/// what it found; what it can search; its categories and its settings. A
/// page of its own on a phone and the folded Duo, the right pane on the
/// open Duo. Reads the shared model, so a test or switch shows at once.
struct V2IndexerDetail: View {
    let id: Int
    let model: V2IndexersModel
    let color: Color
    let onEdit: (SearchIndexerInfo) -> Void
    /// Asks before deleting (each page owns its confirm).
    let onDelete: (SearchIndexerInfo) -> Void
    @Environment(AppModel.self) private var appModel
    @Environment(\.pagePalette) private var page
    @State private var width: CGFloat = 0

    var body: some View {
        if let metric = model.metric(id) {
            content(metric)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        } else {
            Text("This indexer is gone.")
                .font(.subheadline)
                .foregroundStyle(page?.inkMuted ?? Theme.mut)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        }
    }

    private func content(_ metric: IndexerMetric) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            V2IndexerDetailHeader(metric: metric, color: color) { on in
                model.toggle(metric.indexer, on, client: appModel.client)
            }
            actions(metric)
            if metric.state == "backoff" {
                V2IndexerBackoffStrip(metric: metric, color: color) { model.test(metric.indexer, client: appModel.client) }
            }
            V2IndexerStatGrid(metric: metric)
            if width >= 560 {
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 12) {
                        V2IndexerActivityCard(metric: metric, color: color, range: model.range)
                        V2IndexerFoundCard(metric: metric)
                    }
                    VStack(spacing: 12) {
                        V2IndexerSearchCard(metric: metric)
                        V2IndexerCategoriesCard(indexer: metric.indexer)
                    }
                }
            } else {
                V2IndexerActivityCard(metric: metric, color: color, range: model.range)
                V2IndexerFoundCard(metric: metric)
                V2IndexerSearchCard(metric: metric)
                V2IndexerCategoriesCard(indexer: metric.indexer)
            }
            V2IndexerSettingsCard(indexer: metric.indexer, model: model)
        }
    }

    private func actions(_ metric: IndexerMetric) -> some View {
        let indexer = metric.indexer
        let testing = model.testing.contains(indexer.id)
        let result = model.results[indexer.id]
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button { model.test(indexer, client: appModel.client) } label: {
                    Label(testing ? "Testing…" : "Test", systemImage: "bolt").frame(height: 22)
                }
                .disabled(testing)
                Button { onEdit(indexer) } label: {
                    Label("Edit", systemImage: "pencil").frame(height: 22)
                }
                Button { onDelete(indexer) } label: {
                    Image(systemName: "trash").frame(height: 22)
                }
                .tint(Theme.danger)
                .accessibilityLabel("Delete \(indexer.displayName)")
                Spacer(minLength: 6)
                Text("Last used " + (metric.stat?.lastUsedAt.map { FetchFormat.ago($0) } ?? "never"))
                    .font(.footnote)
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            if let result {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    FetchPill(text: result.ok ? "Connected" : "Failed", tone: result.ok ? .ok : .err)
                    if !result.ok {
                        Text(result.message).font(.footnote).foregroundStyle(Theme.danger).lineLimit(3)
                    }
                }
            }
        }
    }
}

/// The detail's head (mock `.ixv-dhd`): the 58pt tile, the name, protocol,
/// priority and source, and the switch (search and RSS together).
struct V2IndexerDetailHeader: View {
    let metric: IndexerMetric
    let color: Color
    let onToggle: (Bool) -> Void
    @Environment(\.pagePalette) private var page

    private var indexer: SearchIndexerInfo { metric.indexer }

    var body: some View {
        HStack(spacing: 14) {
            V2IndexerTile(name: indexer.displayName, color: color, state: metric.state, size: 58)
            VStack(alignment: .leading, spacing: 4) {
                Text(indexer.displayName)
                    .font(.system(size: 26, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(page?.ink ?? Theme.txt)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: 6) {
                    V2IndexerProtocolTag(isTorrent: indexer.isTorrent)
                    Text("Priority \(indexer.priority)" + (indexer.source == "prowlarr" ? " · synced from Prowlarr" : ""))
                        .lineLimit(1)
                    if indexer.source == "prowlarr" {
                        Image("svc-prowlarr").resizable().scaledToFit().frame(width: 14, height: 14)
                            .accessibilityHidden(true)
                    }
                }
                .font(.footnote)
                .foregroundStyle(page?.inkMuted ?? Theme.mut)
            }
            Spacer(minLength: 6)
            Toggle("Enable \(indexer.displayName)", isOn: Binding(get: { indexer.isEnabled }, set: onToggle))
                .labelsHidden()
                .tint(Theme.indigo)
        }
    }
}
