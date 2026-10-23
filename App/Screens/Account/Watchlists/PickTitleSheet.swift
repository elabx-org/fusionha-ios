import SwiftUI
import FusionhaKit

/// "Pick the right title" (web `PickSheet`): the unmatched title and why it
/// wasn't matched, a TMDB search with All / Movies / Series, the candidates,
/// the remember note, then Cancel and Request it in the toolbar and Ignore at
/// the end. One title after another until none remain.
struct PickTitleSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let store: WatchlistsStore
    let view: AutoSourceView
    @State private var pick: PickTitleModel

    init(store: WatchlistsStore, view: AutoSourceView) {
        self.store = store
        self.view = view
        _pick = State(initialValue: PickTitleModel(sourceId: view.sourceId))
    }

    private var tiers: String { AutoSourceDetail(view).uhd ? "HD·1080p + UHD·4K" : "HD·1080p" }

    var body: some View {
        NavigationStack {
            List {
                if let item = pick.item {
                    itemSection(item)
                    searchSection
                    candidates
                    notes
                } else if pick.loadFailed {
                    Text(PickCopy.failed).foregroundStyle(Theme.mut)
                } else {
                    Text(PickCopy.loading).foregroundStyle(Theme.mut)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .tint(Theme.i2)
            .navigationTitle(PickCopy.title)
            .navigationSubtitle(pick.position ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(PickCopy.request, systemImage: "checkmark") { Task { await pick.request(model) } }
                        .disabled(pick.picked == nil || pick.busy)
                }
            }
        }
        .task { await pick.load(model.client) }
        .task(id: pick.searchKey) {
            try? await Task.sleep(for: .milliseconds(300))
            if Task.isCancelled { return }
            await pick.search(model.client)
        }
        .onChange(of: pick.finished) { if pick.finished { dismiss() } }
        .onDisappear { Task { await store.refreshProgress(model.client) } }
        .overlay(alignment: .bottom) { ToastHost().padding(.bottom, 24) }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.bg)
    }

    private func itemSection(_ item: UnmatchedItem) -> some View {
        Section {
            Text(PickCopy.intro(pick.items.count, source: view.name, provider: view.provider))
                .font(.footnote).foregroundStyle(Theme.mut)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.label).font(.headline).foregroundStyle(Theme.txt)
                Text(PickCopy.from(provider: view.provider, source: view.name)).font(.caption).foregroundStyle(Theme.mut)
                if let link = item.sourceUrl.flatMap(URL.init(string:)) {
                    Link(destination: link) {
                        Label(link.host().map { "\($0)\(link.path())" } ?? link.absoluteString, systemImage: "arrow.up.right")
                            .font(.caption).lineLimit(1)
                    }
                }
                why(item).font(.footnote)
            }
        }
        .listRowBackground(AccountStyle.cell)
    }

    private func why(_ item: UnmatchedItem) -> Text {
        let parts = PickCopy.whySentence(item, provider: view.provider)
        var text = Text(PickCopy.why).bold().foregroundStyle(Theme.txt) + Text(" " + parts.before).foregroundStyle(Theme.mut)
        if let slug = parts.slug { text = text + Text(slug).font(.footnote.monospaced()).foregroundStyle(Theme.txt) }
        return text + Text(parts.after).foregroundStyle(Theme.mut)
    }

    private var searchSection: some View {
        Section {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.dim)
                TextField(PickCopy.searchLabel, text: $pick.term)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .accessibilityLabel(PickCopy.searchLabel)
            }
            Picker(PickCopy.kindLabel, selection: $pick.kind) {
                ForEach([SearchKind.all, .movie, .series], id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .listRowBackground(AccountStyle.cell)
    }

    @ViewBuilder
    private var candidates: some View {
        Section {
            if pick.results.isEmpty {
                Text(pick.searching ? PickCopy.searching : pick.searchFailed ? PickCopy.searchFailed : PickCopy.noResults)
                    .font(.footnote).foregroundStyle(Theme.mut)
            } else {
                ForEach(pick.results) { result in
                    PickCandidateRow(result: result, picked: pick.picked == result) { pick.picked = result }
                }
            }
        }
        .listRowBackground(AccountStyle.cell)
    }

    private var notes: some View {
        Section {
            Label {
                Text("\(PickCopy.remember(provider: view.provider)) \(PickCopy.rememberRest)")
                    .font(.footnote).foregroundStyle(Theme.mut)
            } icon: {
                Image(systemName: "shield").foregroundStyle(Theme.dim)
            }
            if pick.picked != nil {
                Text(PickCopy.normalPath(tiers: tiers)).font(.footnote).foregroundStyle(Theme.mut)
            }
            if let note = pick.blocked?.inline {
                Text(note).font(.footnote.weight(.semibold)).foregroundStyle(Theme.missText)
            }
            Button(PickCopy.ignore, systemImage: "nosign") { Task { await pick.ignore(model) } }
                .foregroundStyle(Theme.mut)
                .disabled(pick.busy)
        }
        .listRowBackground(AccountStyle.cell)
    }
}
