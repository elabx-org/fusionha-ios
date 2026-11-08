import SwiftUI
import FusionhaKit

/// Wanted's overview (mock `overview`): missing episodes, below cutoff and
/// upcoming as one-ink bars against the largest.
struct V2WantedOverview: View {
    let totals: WantedPage?

    var body: some View {
        let missing = totals?.missingCount ?? 0
        let cutoff = totals?.cutoffUnmetCount ?? 0
        let upcoming = totals?.upcomingCount ?? 0
        let peak = Double(max(missing, cutoff, upcoming, 1))
        VStack(spacing: 8) {
            V2InkBarRow(label: "Missing", value: missing.formatted(), fraction: Double(missing) / peak)
            V2InkBarRow(label: "Below cutoff", value: cutoff.formatted(), fraction: Double(cutoff) / peak)
            V2InkBarRow(label: "Upcoming", value: upcoming.formatted(), fraction: Double(upcoming) / peak)
        }
        .v2CardStyle(padding: 14)
    }
}

/// The Missing / Cutoff / Upcoming rows as one module in the lazy stack.
struct V2WantedList: View {
    let data: V2WantedModel
    let picked: Int?
    let open: (WantedItem) -> Void

    var body: some View {
        let feed = data.feed
        if !feed.loaded && feed.error == nil {
            ProgressView("Loading wanted titles…").frame(maxWidth: .infinity).padding(.top, 30)
        } else if feed.error != nil && feed.items.isEmpty {
            ContentUnavailableView("The wanted list could not be loaded", systemImage: "exclamationmark.icloud",
                                   description: Text("Check the server and try again."))
        } else if feed.items.isEmpty {
            if data.search.isEmpty {
                ContentUnavailableView(data.tab.emptyMessage, systemImage: "checkmark.circle",
                                       description: data.emptyQuip.map { Text($0) })
            } else {
                ContentUnavailableView.search(text: data.search)
            }
        } else {
            let items = feed.items
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                V2WantedRow(item: item, tab: data.tab, interval: data.interval, searchHighlighted: item.id == picked)
                    .contentShape(Rectangle())
                    .onTapGesture { open(item) }
                    .v2ModuleRow(index, of: items.count, selected: item.id == picked)
                    .foldRow("wanted.\(item.id)")
            }
            ActFooter(total: feed.total, loaded: items.count, hasMore: feed.hasMore, loading: feed.loadingMore,
                      noun: data.tab.noun, query: data.search) { Task { await feed.loadMore() } }
        }
    }
}

/// The 4K Available rows, with the observer's off state (Turn on observing).
struct V2WantedFourKList: View {
    let data: V2WantedModel
    let picked: Int?
    let open: (FourKAvailableItem) -> Void
    let add: (FourKAvailableItem) -> Void
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.pagePalette) private var page

    var body: some View {
        let feed = data.fourkFeed
        Text("Releases seen in 4K for titles you only have in HD. Nothing is grabbed automatically.")
            .font(.system(size: 12.5))
            .foregroundStyle(page?.inkMuted ?? Theme.mut)
            .fixedSize(horizontal: false, vertical: true)
            .v2ScopeBlock(10)
        if !feed.loaded && feed.error == nil {
            ProgressView("Loading 4K availability…").frame(maxWidth: .infinity).padding(.top, 30)
        } else if feed.error != nil && feed.items.isEmpty {
            ContentUnavailableView("The 4K feed could not be loaded", systemImage: "exclamationmark.icloud",
                                   description: Text("Check the server and try again."))
        } else if feed.items.isEmpty {
            empty
        } else {
            let items = feed.items
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                V2FourKRow(item: item) { add(item) }
                    .contentShape(Rectangle())
                    .onTapGesture { open(item) }
                    .v2ModuleRow(index, of: items.count, selected: item.id == picked)
                    .foldRow("fourk.\(item.id)")
            }
            ActFooter(total: feed.total, loaded: items.count, hasMore: feed.hasMore, loading: feed.loadingMore,
                      noun: WantedTab.fourk.noun, query: data.search) { Task { await feed.loadMore() } }
        }
    }

    @ViewBuilder
    private var empty: some View {
        if !data.search.isEmpty {
            ContentUnavailableView.search(text: data.search)
        } else {
            let observer = data.settings?.uhdAvailableObserverEnabled
            ContentUnavailableView {
                Label(observer == false ? "The 4K observer is off" : "Nothing 4K spotted yet", systemImage: "sparkles")
            } description: {
                Text(observer == false
                     ? "Turn it on to start spotting 4K during your normal searches."
                     : "Genuine 2160p releases seen during your normal searches show up here.")
            } actions: {
                if observer == false {
                    Button("Turn on observing") { Task { await data.enableObserver(model.client, toaster: toaster) } }
                        .buttonStyle(.glass)
                }
            }
        }
    }
}
