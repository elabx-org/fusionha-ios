import SwiftUI
import FusionhaKit

/// v2's Activity › Wanted (plan S10, mock activity-log.js `wanted` on the W1
/// ground). v1's data and searches (`V2WantedModel`); v2's look: the
/// overview as one-ink bars, Missing | Cutoff | Upcoming | 4K as a
/// segmented picker with counts, Search all as the one prominent glass
/// button, then one module of rows with T5 tickets and a round search
/// menu each. 4K rows carry the HD ticket and Add 4K version instead of
/// v1's rails. A row opens its decision: the right page on the open Duo,
/// a sheet on the phone.
struct V2WantedScope: View {
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.paneSize) private var pane
    @Environment(\.duoOpen) private var duoOpen
    @Environment(\.bookPose) private var bookPose
    @Environment(\.motionEnabled) private var motion
    @State private var data = V2WantedModel()
    @State private var picked: Int?
    @State private var sheetItem: WantedItem?
    @State private var sheetFourK: FourKAvailableItem?
    @State private var addEditionFor: FourKAvailableItem?

    private var split: V2ScopeSplit { V2ScopeSplit(width: pane.width, duoOpen: duoOpen, bookPose: bookPose) }

    var body: some View {
        @Bindable var data = data
        V2ScopeColumns(split: split) {
            V2ScopeList(gutter: split.gutter) { caption } content: { content }
        } right: {
            V2RightPage { rightPage }
        }
        .v2PageGround(art: groundArt)
        .searchable(text: $data.searchInput, placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: "Search by title")
        .refreshable { await data.reloadAll(model.client) }
        .task { await data.loadTotals(model.client) }
        .task { await data.loadSettings(model.client) }
        .task(id: data.searchInput) { await data.debounce() }
        .task(id: "\(data.tab.rawValue)|\(data.search)") { await data.loadFeed(model.client) }
        .onChange(of: data.tab) { picked = nil }
        .onChange(of: split.splits) { _, now in carryPick(splits: now) }
        .sheet(item: $sheetItem) { item in
            V2ScopeSheet(title: item.title, art: item.posterUrl) {
                WantedDecisionPane(item: item, tab: data.tab, interval: data.interval)
            }
            .environment(model)
        }
        .sheet(item: $sheetFourK) { item in
            V2ScopeSheet(title: item.title, art: item.posterUrl) {
                WantedFourKPane(item: item) {
                    sheetFourK = nil
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(450))
                        addEditionFor = item
                    }
                }
            }
            .environment(model)
        }
        .sheet(item: $addEditionFor) { item in
            WantedAddEditionSheet(item: item) {
                addEditionFor = nil
                toaster.show("Added a 4K version for \(item.title)", tone: .success)
                Task { await data.reloadAll(model.client) }
            } onCancel: { addEditionFor = nil }
            .environment(model)
        }
    }

    private var caption: some View {
        let lead = data.totals == nil ? "Loading…" : "\(data.count(.missing).formatted()) titles missing"
        var rest = ["\(data.count(.cutoff).formatted()) below cutoff", "\(data.count(.upcoming).formatted()) upcoming"]
        if data.count(.fourk) > 0 { rest.append("\(data.count(.fourk).formatted()) seen in 4K") }
        return V2ScopeCaption(lead: lead, rest: data.totals == nil ? [] : rest)
    }

    @ViewBuilder
    private var content: some View {
        @Bindable var data = data
        if data.totals == nil && !data.totalsFailed {
            ProgressView("Loading wanted titles…").frame(maxWidth: .infinity).padding(.top, 40)
        } else if data.totalsFailed && data.totals == nil {
            ContentUnavailableView("The wanted list could not be loaded", systemImage: "exclamationmark.icloud",
                                   description: Text("Check the server and try again."))
        } else {
            V2WantedOverview(totals: data.totals).v2ScopeBlock()
            Picker("Wanted", selection: $data.tab.animation(motion ? .snappy(duration: 0.25) : nil)) {
                ForEach(WantedTab.allCases, id: \.self) { t in
                    Text(data.count(t) > 0 ? "\(t.shortLabel) \(data.count(t).formatted())" : t.shortLabel).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .v2ScopeBlock()
            searchAll
            if data.tab == .fourk {
                V2WantedFourKList(data: data, picked: split.splits ? openFourK?.id : nil, open: showFourK,
                                  add: { addEditionFor = $0 })
            } else {
                V2WantedList(data: data, picked: split.splits ? openItem?.id : nil, open: showItem)
            }
        }
    }

    @ViewBuilder
    private var searchAll: some View {
        if data.tab == .missing || data.tab == .cutoff {
            Button {
                Task { await data.searchAll(model.client, toaster: toaster) }
            } label: {
                Label(data.searchingAll ? "Searching…" : (data.tab == .cutoff ? "Search all upgrades" : "Search all missing"),
                      systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(data.count(data.tab) == 0 || data.searchingAll)
            .v2ScopeBlock()
        }
    }

    @ViewBuilder
    private var rightPage: some View {
        if data.tab == .fourk {
            if let item = openFourK {
                WantedFourKPane(item: item) { addEditionFor = item }.id(item.id)
            }
        } else if let item = openItem {
            WantedDecisionPane(item: item, tab: data.tab, interval: data.interval).id(item.id)
        }
    }

    // MARK: Selection

    private var openItem: WantedItem? {
        let items = data.feed.items
        return items.first { $0.id == picked } ?? items.first
    }

    private var openFourK: FourKAvailableItem? {
        let items = data.fourkFeed.items
        return items.first { $0.id == picked } ?? items.first
    }

    private func showItem(_ item: WantedItem) {
        if split.splits {
            withAnimation(motion ? .snappy(duration: 0.25) : nil) { picked = item.id }
        } else {
            sheetItem = item
        }
    }

    private func showFourK(_ item: FourKAvailableItem) {
        if split.splits {
            withAnimation(motion ? .snappy(duration: 0.25) : nil) { picked = item.id }
        } else {
            sheetFourK = item
        }
    }

    /// Fold continuity (`FoldPick`): the picked title moves between the
    /// right page and its sheet, for the tab on screen.
    private func carryPick(splits: Bool) {
        if data.tab == .fourk {
            let next = FoldPick(picked: picked, sheet: sheetFourK?.id).reconciled(splits: splits)
            picked = next.picked
            if sheetFourK?.id != next.sheet { sheetFourK = data.fourkFeed.items.first { $0.id == next.sheet } }
        } else {
            let next = FoldPick(picked: picked, sheet: sheetItem?.id).reconciled(splits: splits)
            picked = next.picked
            if sheetItem?.id != next.sheet { sheetItem = data.feed.items.first { $0.id == next.sheet } }
        }
    }

    /// The first wanted title (the chosen one on the open Duo).
    private var groundArt: URL? {
        let poster = data.tab == .fourk ? openFourK?.posterUrl : openItem?.posterUrl
        let id = data.tab == .fourk ? openFourK?.id : openItem?.id
        let backdrop = id.flatMap { id in model.library.first { $0.id == id }?.backdropUrl }
        return PageArtSource.url(backdrop: backdrop, poster: poster)
    }
}
