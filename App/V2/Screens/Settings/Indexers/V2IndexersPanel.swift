import SwiftUI
import FusionhaKit

/// Settings › Indexers in the S1 look (mock settings-ix.js, owner
/// 2026-11-04): the fleet card, Test all · Add, every indexer as a rich row
/// grouped by search priority, and a detail per indexer: pushed on a phone
/// and the folded Duo, beside the list when the page is wide (the open Duo
/// with the settings list hidden). Sort and protocol filter in the bar.
/// The calls, sheets and confirms are v1's `IndexersPanel`.
struct V2IndexersPanel: View {
    @Environment(AppModel.self) private var appModel
    @State private var model = V2IndexersModel()
    @State private var sort: IndexersPanel.SortKey = .share
    @State private var protocolFilter = "ALL"
    @State private var editing: SearchIndexerInfo?
    @State private var adding = false
    @State private var width: CGFloat = 0
    /// The indexer shown beside the list when wide.
    @State private var selected: Int?
    /// The indexer pushed on a phone.
    @State private var pushed: Int?
    @State private var headerGone = false

    private var wide: Bool { width >= 720 }

    private var rows: [IndexerMetric] {
        let all = model.metrics
        let filtered = protocolFilter == "ALL" ? all : all.filter { $0.indexer.protocol == protocolFilter }
        return filtered.sorted { a, b in
            switch sort {
            case .byYield: return a.yieldValue > b.yieldValue
            case .grabs: return a.grabsRange > b.grabsRange
            case .success: return (a.successPct ?? -1) > (b.successPct ?? -1)
            case .name: return a.indexer.name.localizedCompare(b.indexer.name) == .orderedAscending
            case .share: return a.share > b.share
            }
        }
    }

    private var sortLabel: String { sort == .share ? "Grab share" : sort.rawValue }

    var body: some View {
        layout
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .v2SettingsChrome(slug: "indexers", titleShown: headerGone, toaster: model.toaster,
                              confirm: $model.confirm)
            .toolbar { ToolbarItem(placement: .primaryAction) { filterMenu } }
            .task { await model.load(appModel.client) }
            .task(id: model.range) { await model.loadStats(appModel.client) }
            .sheet(isPresented: $adding) {
                IndexerSheet(indexer: nil) { await model.load(appModel.client) }
            }
            .sheet(item: $editing) { indexer in
                IndexerSheet(indexer: indexer) { await model.load(appModel.client) }
            }
            .navigationDestination(item: $pushed) { id in
                V2IndexerDetailPage(id: id, model: model, color: color(id), onEdit: { editing = $0 })
            }
            .onChange(of: wide) { _, isWide in
                // Fold continuity: the open indexer moves between the pushed
                // page and the pane beside the list.
                if isWide, let id = pushed { selected = id; pushed = nil }
                if !isWide, let id = selected { pushed = id }
            }
    }

    @ViewBuilder
    private var layout: some View {
        if wide {
            HStack(spacing: 0) {
                list(beside: true)
                    .frame(width: min(400, width * 0.45))
                ModuleMetrics.hairline(light: Theme.isLight).frame(width: 0.5)
                    .ignoresSafeArea(edges: .bottom)
                ScrollView {
                    if let id = selected ?? rows.first?.id {
                        V2IndexerDetail(id: id, model: model, color: color(id), onEdit: { editing = $0 },
                                        onDelete: { model.confirm = model.deleteConfirm($0, client: appModel.client) { selected = nil } })
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                            .padding(.bottom, 64)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            list(beside: false)
        }
    }

    private func list(beside: Bool) -> some View {
        V2IndexerListColumn(model: model, rows: rows, sortLabel: sortLabel,
                            selected: beside ? (selected ?? rows.first?.id) : nil, beside: beside,
                            range: $model.range, headerGone: $headerGone, colorFor: color,
                            open: { id in if beside { selected = id } else { pushed = id } },
                            onAdd: { adding = true })
    }

    private func color(_ id: Int) -> Color {
        V2IndexerIdentity.color(id, among: model.indexers.map(\.id))
    }

    /// Sort and protocol (v1's toolbar), as one bar menu.
    private var filterMenu: some View {
        Menu {
            Picker("Sort by", selection: $sort) {
                ForEach(IndexersPanel.SortKey.allCases) { Text($0.rawValue).tag($0) }
            }
            Picker("Protocol", selection: $protocolFilter) {
                Text("All").tag("ALL")
                Text("Usenet").tag("USENET")
                Text("Torrent").tag("TORRENT")
            }
        } label: {
            Label("Sort and filter", systemImage: protocolFilter == "ALL"
                  ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
        }
        .accessibilityLabel("Sort by \(sort.rawValue), \(protocolFilter == "ALL" ? "all protocols" : protocolFilter.capitalized)")
    }
}

/// One indexer pushed on a phone and the folded Duo: the detail on the
/// Indexers tint, with its own delete confirm and the shared toasts.
struct V2IndexerDetailPage: View {
    let id: Int
    let model: V2IndexersModel
    let color: Color
    let onEdit: (SearchIndexerInfo) -> Void
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirm: FetchConfirm?

    var body: some View {
        ScrollView {
            V2IndexerDetail(id: id, model: model, color: color, onEdit: onEdit,
                            onDelete: { confirm = model.deleteConfirm($0, client: appModel.client) { dismiss() } })
                .padding(.horizontal, Theme.pageGutter)
                .padding(.top, 8)
                .padding(.bottom, 64)
        }
        .refreshable { await model.load(appModel.client) }
        .navigationTitle(model.metric(id)?.indexer.displayName ?? "Indexer")
        .toolbarTitleDisplayMode(.inline)
        .fetchToasts(model.toaster)
        .fetchConfirm($confirm)
        .v2SettingsGround("indexers")
    }
}
