import SwiftUI
import FusionhaKit

/// Tab 3 (web `LastRunTab`): pick a list; its recent runs, the newest open
/// with its outcome bar, legend and the titles it saw.
struct ImportListRunsTab: View {
    @Environment(AppModel.self) private var model
    let store: ImportListsStore
    let onReview: (ImportList) -> Void
    @State private var picked: Int?
    @State private var runs: [ImportListRun]?

    private var listId: Int? { picked ?? store.lists.first?.id }

    var body: some View {
        if store.lists.isEmpty {
            Section { Text("No import lists yet.").foregroundStyle(Theme.mut) }
        } else {
            Section {
                Picker("List", selection: Binding(get: { listId }, set: { picked = $0 })) {
                    ForEach(store.lists) { Text($0.name).tag(Int?.some($0.id)) }
                }
                .pickerStyle(.menu)
            }
            .task(id: listId) { await load() }
            if let runs, let list = store.list(listId) {
                if runs.isEmpty {
                    Section { Text(ImportListCopy.noRuns).foregroundStyle(Theme.mut) }
                }
                ForEach(Array(runs.enumerated()), id: \.element.id) { index, run in
                    ImportListRunCard(run: run, site: list.site, startsOpen: index == 0) { onReview(list) }
                }
            } else {
                Section { SettingsLoadingRow() }
            }
        }
    }

    private func load() async {
        guard let client = model.client, let id = listId else { return }
        runs = nil
        runs = (try? await client.importListRuns(id)) ?? []
    }
}

/// One run (web `RunCard`): a header, then (open) the outcome bar, its legend
/// and the items it saw, with Review on an unmatched one.
struct ImportListRunCard: View {
    @Environment(AppModel.self) private var model
    let run: ImportListRun
    let site: SourceProvider
    let startsOpen: Bool
    let onReview: () -> Void
    @State private var open: Bool?
    @State private var items: [ImportListItem]?

    private var isOpen: Bool { open ?? startsOpen }

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: Binding(get: { isOpen }, set: { open = $0 })) {
                if let error = run.error { Text(error).font(.footnote).foregroundStyle(Theme.danger) }
                ImportListOutcomeBar(counts: run.counts)
                ImportListOutcomeLegend(counts: run.counts)
                itemRows
            } label: {
                header
            }
        }
        .task(id: isOpen) {
            guard isOpen, items == nil, let client = model.client else { return }
            items = (try? await client.importListRunItems(run.id)) ?? []
        }
    }

    private var header: some View {
        let state = ImportListCopy.runState(run)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                ProviderTile(provider: site, size: 20, small: true)
                Text(ServerTime.parse(run.startedAt)?.formatted(.dateTime.month(.abbreviated).day().hour().minute()) ?? run.startedAt)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
                Spacer(minLength: 4)
                ImportListStatusPill(look: state)
            }
            Text([ImportListCopy.runDuration(run), isOpen ? nil : ImportListCopy.runLine(run.counts)]
                    .compactMap { $0 }.joined(separator: " · "))
                .font(.caption).foregroundStyle(Theme.mut)
        }
    }

    @ViewBuilder private var itemRows: some View {
        if let items {
            if items.isEmpty { Text(ImportListCopy.noRunItems).font(.footnote).foregroundStyle(Theme.mut) }
            ForEach(items) { item in
                HStack(spacing: 8) {
                    Text(item.label).font(.subheadline).foregroundStyle(Theme.txt).lineLimit(2)
                    Spacer(minLength: 4)
                    ImportListStatusPill(look: ImportListCopy.outcome(item.outcome))
                    if item.outcome == "UNMATCHED" {
                        Button("Review", action: onReview).buttonStyle(.web()).font(.caption)
                    }
                }
            }
        } else {
            SettingsLoadingRow()
        }
    }
}

/// The run's outcomes as one bar, each in its status colour.
struct ImportListOutcomeBar: View {
    let counts: ImportListRunCounts

    var body: some View {
        let parts = ImportListCopy.segments(counts).filter { $0.count > 0 }
        let total = max(1, counts.total)
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(parts, id: \.outcome) { part in
                    Capsule()
                        .fill(ImportListCopy.outcome(part.outcome).tone?.color ?? Theme.dim)
                        .frame(width: max(2, geo.size.width * CGFloat(part.count) / CGFloat(total) - 2))
                }
            }
        }
        .frame(height: 6)
        .accessibilityElement()
        .accessibilityLabel("Outcomes")
    }
}

/// "Added 3 · Already in library 12 · …" with each colour's dot.
struct ImportListOutcomeLegend: View {
    let counts: ImportListRunCounts

    var body: some View {
        ActFlow(spacing: 12, lineSpacing: 4) {
            ForEach(ImportListCopy.segments(counts), id: \.outcome) { part in
                let look = ImportListCopy.outcome(part.outcome)
                HStack(spacing: 4) {
                    Circle().fill(look.tone?.color ?? Theme.dim).frame(width: 6, height: 6)
                    Text("\(look.word) \(Text("\(part.count)").bold().foregroundStyle(Theme.txt))")
                }
                .font(.caption).foregroundStyle(Theme.mut)
            }
        }
    }
}
