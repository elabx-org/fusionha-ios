import SwiftUI
import FusionhaKit

/// Settings › Download Clients in the S1 look (mock settings-v2.js
/// "Download Clients"): the page header with the section tile on the warm
/// Fetching tint, one card per client under Usenet and Torrent, then the
/// decypharr stages and Auto-fix groups. Same calls and sheets as v1's
/// `DownloadClientsPanel`; only the look differs.
struct V2DownloadClientsPanel: View {
    @Environment(AppModel.self) private var model
    @State private var clients: [DownloadClientInfo] = []
    @State private var loaded = false
    @State private var error: String?
    @State private var results: [Int: ConnectionTestResult] = [:]
    @State private var testing: Set<Int> = []
    @State private var editing: DownloadClientInfo?
    @State private var adding = false
    @State private var toaster = FetchToaster()
    @State private var confirm: FetchConfirm?

    private var usenet: [DownloadClientInfo] { ordered(clients.filter { !$0.isTorrent }) }
    private var torrent: [DownloadClientInfo] { ordered(clients.filter(\.isTorrent)) }

    var body: some View {
        V2SettingsPage(slug: "clients", subtitle: "Usenet and torrent, with categories per kind.",
                       toaster: toaster, confirm: $confirm, refresh: load) {
            if !loaded || error != nil { FetchLoading(error: error) }
            ImportRulesNoteView(clients: clients)
            group("Usenet", usenet, offset: 0)
            group("Torrent", torrent, offset: usenet.count)
            if loaded, clients.isEmpty, error == nil {
                FetchEmpty(text: "No download clients yet. Add SABnzbd or qBittorrent to start grabbing.")
                    .padding(.top, 8)
            }
            V2ClientExtras()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add client", systemImage: "plus") { adding = true }
            }
        }
        .task { await load() }
        .sheet(isPresented: $adding) {
            DownloadClientSheet(client: nil) { await load() }
        }
        .sheet(item: $editing) { client in
            DownloadClientSheet(client: client) { await load() }
        }
    }

    @ViewBuilder
    private func group(_ title: String, _ list: [DownloadClientInfo], offset: Int) -> some View {
        if !list.isEmpty {
            V2SettingsGroupHeader(title: title)
            VStack(spacing: 12) {
                ForEach(Array(list.enumerated()), id: \.element.id) { index, client in
                    V2DownloadClientCard(client: client, result: results[client.id],
                                         testing: testing.contains(client.id),
                                         onToggle: { toggle(client, $0) },
                                         onTest: { runTest(client) },
                                         onEdit: { editing = client },
                                         onDelete: { askDelete(client) })
                        .fetchReveal(offset + index)
                }
            }
        }
    }

    /// Priority first (the order fusionha tries them), then by name.
    private func ordered(_ list: [DownloadClientInfo]) -> [DownloadClientInfo] {
        list.sorted { a, b in
            let pa = a.priority ?? Int.max, pb = b.priority ?? Int.max
            return pa != pb ? pa < pb : a.name.localizedCompare(b.name) == .orderedAscending
        }
    }

    // MARK: Actions (v1's DownloadClientsPanel)

    private func load() async {
        guard let client = model.client else { return }
        do {
            clients = try await client.configList(.downloadClients)
            error = nil
        } catch {
            self.error = error.settingsMessage
        }
        loaded = true
    }

    private func runTest(_ dc: DownloadClientInfo) {
        guard let client = model.client else { return }
        testing.insert(dc.id)
        Task {
            do {
                results[dc.id] = try await client.configTest(.downloadClients, id: dc.id)
            } catch {
                results[dc.id] = ConnectionTestResult(ok: false, message: error.settingsMessage)
            }
            testing.remove(dc.id)
        }
    }

    private func toggle(_ dc: DownloadClientInfo, _ on: Bool) {
        guard let client = model.client else { return }
        Task {
            do {
                try await client.configUpdate(.downloadClients, id: dc.id, ["enable": .bool(on)])
                await load()
            } catch { toaster.error(error) }
        }
    }

    private func askDelete(_ dc: DownloadClientInfo) {
        confirm = FetchConfirm(title: "Delete \(dc.name)?",
                               message: "fusionha stops sending grabs to this client. Its queue is not touched.") {
            Task {
                guard let client = model.client else { return }
                do {
                    try await client.configDelete(.downloadClients, id: dc.id)
                    await load()
                } catch { toaster.error(error, title: "Could not delete the client") }
            }
        }
    }
}
