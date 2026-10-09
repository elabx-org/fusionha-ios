import SwiftUI
import FusionhaKit

/// Settings → Download Clients (`DownloadClientsPanel.tsx`): one card per client
/// with a live Test pill, enable toggle, edit and delete; "+ Add client" opens the
/// two-step sheet (SABnzbd / qBittorrent picker → the full config form with Test).
struct DownloadClientsPanel: View {
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

    var body: some View {
        FetchingPage(slug: "clients", toaster: toaster, confirm: $confirm, refresh: load) {
            if !loaded || error != nil { FetchLoading(error: error) }
            VStack(spacing: 12) {
                ForEach(Array(clients.enumerated()), id: \.element.id) { index, client in
                    card(client).fetchReveal(index)
                }
            }
            .padding(.bottom, 14)
            if loaded, clients.isEmpty, error == nil {
                FetchEmpty(text: "No download clients yet — add SABnzbd or qBittorrent to start grabbing.")
                    .padding(.bottom, 14)
            }
            Button("+ Add client") { adding = true }.buttonStyle(.web())
        }
        .task { await load() }
        .sheet(isPresented: $adding) {
            DownloadClientSheet(client: nil) { await load() }
        }
        .sheet(item: $editing) { client in
            DownloadClientSheet(client: client) { await load() }
        }
    }

    private func card(_ client: DownloadClientInfo) -> some View {
        let result = results[client.id]
        return HStack(alignment: .center, spacing: 14) {
            FetchIconTile(systemName: "arrow.down.to.line")
            VStack(alignment: .leading, spacing: 2) {
                FetchFlow(spacing: 8, lineSpacing: 4) {
                    Text(client.name).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(1)
                    if client.enable == false { FetchPill(text: "Disabled") }
                    if testing.contains(client.id) {
                        ProgressView().controlSize(.mini)
                    } else if let result {
                        FetchPill(text: result.ok ? "Connected" : "Failed", tone: result.ok ? .ok : .err)
                    }
                }
                (Text(client.isTorrent ? "Torrent · " : "Usenet · ")
                    + Text("\(client.host):\(String(client.port))").font(.system(size: 12, design: .monospaced)))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.mut)
                    .lineLimit(1)
                if let result, !result.ok {
                    Text(result.message).font(.system(size: 11.5)).foregroundStyle(Theme.danger).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                Button("Test") { runTest(client) }
                    .buttonStyle(.web())
                    .disabled(testing.contains(client.id))
                    .accessibilityLabel("Test \(client.name)")
                FetchIconButton(systemName: "pencil", label: "Edit \(client.name)") { editing = client }
                FetchIconButton(systemName: "trash", label: "Delete \(client.name)", danger: true) { askDelete(client) }
            }
        }
        .fetchCard()
        .contextMenu {
            Button { toggle(client) } label: {
                Label(client.enable == false ? "Enable" : "Disable", systemImage: "power")
            }
        }
    }

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

    private func toggle(_ dc: DownloadClientInfo) {
        guard let client = model.client else { return }
        Task {
            do {
                try await client.configUpdate(.downloadClients, id: dc.id, ["enable": .bool(dc.enable == false)])
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
