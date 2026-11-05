import SwiftUI
import FusionhaKit

/// One wanted title's searches (v1 `WantedCardView`'s calls, kept as they
/// are): an engine search of the title or one episode, and the gradual
/// one-episode-at-a-time search, whose run the row then follows.
@MainActor
@Observable
final class V2WantedSearch {
    private(set) var searchingKey: String?
    var gradualRun: Int?
    private(set) var gradualTotal = 0

    func run(_ item: WantedItem, label: String, key: String, episodeId: Int? = nil, missingOnly: Bool = false,
             client: APIClient?, toaster: ActToaster) {
        searchingKey = key
        Task {
            defer { searchingKey = nil }
            do {
                try await client?.runSearch(itemId: item.id, episodeId: episodeId, missingOnly: missingOnly)
                toaster.show("Searching for \(label)")
            } catch {
                toaster.error(error)
            }
        }
    }

    func startGradual(_ item: WantedItem, missingOnly: Bool, client: APIClient?, toaster: ActToaster) async {
        guard let client else { return }
        let label = missingOnly ? "\(item.title) (missing only)" : item.title
        do {
            let start = try await client.startGradualSearch(itemId: item.id, missingOnly: missingOnly)
            gradualTotal = start.total
            if start.total == 0 {
                toaster.show(missingOnly ? "\(label): no missing episodes — nothing to search"
                                         : "\(label): all episodes meet the cutoff — nothing to upgrade", tone: .warning)
            } else if let runId = start.runId {
                gradualRun = runId
            }
        } catch let error as APIError where error.status == 409 && error.detailRunId != nil {
            gradualRun = error.detailRunId
        } catch {
            toaster.show("Couldn't start the gradual search for \(label)", tone: .error)
        }
    }
}

/// The round search button's menu (mock `wMenu`): Search all, Search missing
/// only, Search each episode, then Interactive search and Why this decision.
struct V2WantedSearchMenu: View {
    let item: WantedItem
    let tab: WantedTab
    let search: V2WantedSearch
    var highlighted = false
    var size: CGFloat = 36
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster

    var body: some View {
        Menu {
            if tab == .missing || tab == .cutoff {
                Button("Search all", systemImage: "magnifyingglass") {
                    search.run(item, label: item.title, key: "title", client: model.client, toaster: toaster)
                }
                if item.kind == .series {
                    Button("Search missing only", systemImage: "magnifyingglass") {
                        Task { await search.startGradual(item, missingOnly: true, client: model.client, toaster: toaster) }
                    }
                    Button("Search each episode", systemImage: "list.bullet") {
                        Task { await search.startGradual(item, missingOnly: false, client: model.client, toaster: toaster) }
                    }
                } else {
                    Button("Search missing only", systemImage: "magnifyingglass") {
                        search.run(item, label: "\(item.title) (missing only)", key: "title", missingOnly: true,
                                   client: model.client, toaster: toaster)
                    }
                }
                Divider()
            }
            Button("Interactive search", systemImage: "person") { model.interactiveSearch(item.id, tier: nil) }
            Button("Why this decision", systemImage: "info.circle") { model.open(item.id, tab: .searches) }
            Button("Open title", systemImage: "arrow.up.right.square") { model.open(item.id) }
        } label: {
            ZStack {
                if search.searchingKey == "title" {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: "magnifyingglass").font(.system(size: size * 0.42, weight: .semibold))
                }
            }
            .foregroundStyle(highlighted ? Theme.onAccent : Theme.txt)
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .glassEffect(highlighted ? .regular.tint(Theme.primary).interactive() : .regular.interactive(), in: Circle())
        .accessibilityLabel("Search for \(item.title)")
    }
}
