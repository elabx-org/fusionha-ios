import SwiftUI
import FusionhaKit

/// Settings → Connect (`ConnectPanel.tsx`): fusionha's own Discord / Telegram /
/// webhook notification agents (kind chip, enable switch, event summary, Test),
/// the two-step add sheet (provider picker → form with Test), and the webhooks
/// external tools registered on the virtual instances (`ArrWebhooksCard`).
struct ConnectPanel: View {
    @Environment(AppModel.self) private var model
    @State private var agents: [NotificationAgentInfo] = []
    @State private var groups: [ArrWebhookGroup] = []
    @State private var loaded = false
    @State private var groupsLoaded = false
    @State private var error: String?
    @State private var results: [Int: ConnectionTestResult] = [:]
    @State private var testing: Set<Int> = []
    @State private var editing: NotificationAgentInfo?
    @State private var adding = false
    @State private var toaster = FetchToaster()
    @State private var confirm: FetchConfirm?

    var body: some View {
        FetchingPage(slug: "connect", toaster: toaster, confirm: $confirm, refresh: load) {
            if !loaded || error != nil { FetchLoading(error: error) }
            VStack(spacing: 12) {
                ForEach(Array(agents.enumerated()), id: \.element.id) { index, agent in
                    card(agent).fetchReveal(index)
                }
            }
            .padding(.bottom, 14)
            Button("+ Add notification") { adding = true }.buttonStyle(.web())
                .padding(.bottom, 24)
            webhooksCard
        }
        .task { await load() }
        .sheet(isPresented: $adding) {
            NotificationAgentSheet(agent: nil) { await load() }
        }
        .sheet(item: $editing) { agent in
            NotificationAgentSheet(agent: agent) { await load() }
        }
    }

    private func card(_ agent: NotificationAgentInfo) -> some View {
        let result = results[agent.id]
        let meta = AgentKindMeta(agent.agentKind)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                FetchIconTile(systemName: "bell")
                VStack(alignment: .leading, spacing: 2) {
                    FetchFlow(spacing: 8, lineSpacing: 4) {
                        Text(agent.name).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(1)
                        AgentKindChip(meta: meta)
                        if !agent.enabled { FetchPill(text: "Disabled") }
                        if testing.contains(agent.id) {
                            ProgressView().controlSize(.mini)
                        } else if let result {
                            FetchPill(text: result.ok ? "Sent" : "Failed", tone: result.ok ? .ok : .err)
                        }
                    }
                    Text(eventSummary(agent)).font(.system(size: 12)).foregroundStyle(Theme.mut).lineLimit(2)
                }
                Spacer(minLength: 0)
                Toggle("Enable \(agent.name)", isOn: Binding(get: { agent.enabled }, set: { toggle(agent, $0) }))
                    .labelsHidden()
                    .tint(Theme.indigo)
            }
            HStack(spacing: 2) {
                Spacer()
                Button("Test") { runTest(agent) }
                    .buttonStyle(.web())
                    .disabled(testing.contains(agent.id))
                    .accessibilityLabel("Test \(agent.name)")
                FetchIconButton(systemName: "pencil", label: "Edit \(agent.name)") { editing = agent }
                FetchIconButton(systemName: "trash", label: "Delete \(agent.name)", danger: true) { askDelete(agent) }
            }
        }
        .fetchCard()
    }

    private func eventSummary(_ agent: NotificationAgentInfo) -> String {
        let on = agentEvents.filter { agent.events[$0.key] == true }.map { e -> String in
            let short = e.label.replacingOccurrences(of: "On ", with: "")
            return short.prefix(1).uppercased() + short.dropFirst()
        }
        return on.isEmpty ? "No events" : on.joined(separator: " · ")
    }

    // MARK: Registered by external tools

    private var webhooksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Registered by external tools").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt)
                Text("webhooks decypharr / Overseerr registered on the virtual arr instances")
                    .font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
            if !groupsLoaded {
                Text("Loading connections…").font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            } else if groups.isEmpty {
                Text("No external connections registered.").font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            } else {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(group.instanceLabel).font(.system(size: 12.5, weight: .bold)).foregroundStyle(Theme.txt)
                            MonoText(group.instanceSlug, color: Theme.dim)
                        }
                        ForEach(group.notifications) { webhook in
                            webhookRow(webhook)
                                .transition(.opacity)
                        }
                    }
                }
            }
            NavigationLink {
                SettingsWebPanel(slug: "connect")
            } label: {
                Text("+ Add webhook")
            }
            .buttonStyle(.web())
        }
        .fetchCard(padding: 14, radius: 14)
    }

    private func webhookRow(_ webhook: ArrWebhookGroup.Webhook) -> some View {
        let chips: [(Bool?, String)] = [(webhook.onGrab, "Grab"), (webhook.onImport, "Import"), (webhook.onUpgrade, "Upgrade"),
                                        (webhook.onRename, "Rename"), (webhook.onDelete, "Delete")]
        return HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(webhook.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                    if let source = webhook.source { FetchChip(text: source, color: Theme.cyan, border: Theme.cyan.opacity(0.35)) }
                }
                if let url = webhook.url { MonoText(url).lineLimit(1).truncationMode(.middle) }
                FetchFlow(spacing: 4, lineSpacing: 4) {
                    ForEach(chips.filter { $0.0 == true }, id: \.1) { _, label in
                        FetchChip(text: label, size: 9.5)
                    }
                }
            }
            Spacer(minLength: 0)
            NavigationLink {
                SettingsWebPanel(slug: "connect")
            } label: {
                Image(systemName: "pencil").font(.system(size: 14)).foregroundStyle(Theme.dim).frame(width: 34, height: 34)
            }
            .accessibilityLabel("Edit \(webhook.name)")
            FetchIconButton(systemName: "trash", label: "Remove \(webhook.name)", danger: true) {
                confirm = FetchConfirm(
                    title: "Remove “\(webhook.name)”?",
                    message: "Registered by \(webhook.source ?? "an external tool"). The external tool may re-register it on its next sync.",
                    action: "Remove") {
                    Task {
                        guard let client = model.client else { return }
                        do {
                            try await client.deleteArrWebhook(id: webhook.id)
                            await loadGroups()
                        } catch { toaster.error(error, title: "Could not remove the connection") }
                    }
                }
            }
        }
        .padding(10)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.line))
    }

    // MARK: Actions

    private func load() async {
        guard let client = model.client else { return }
        do {
            agents = try await client.configList(.notificationAgents)
            error = nil
        } catch {
            self.error = error.settingsMessage
        }
        loaded = true
        await loadGroups()
    }

    private func loadGroups() async {
        guard let client = model.client else { return }
        groups = (try? await client.arrWebhooks()) ?? []
        groupsLoaded = true
    }

    private func toggle(_ agent: NotificationAgentInfo, _ on: Bool) {
        guard let client = model.client else { return }
        Task {
            do {
                try await client.configUpdate(.notificationAgents, id: agent.id, ["enabled": .bool(on)])
                await load()
            } catch { toaster.error(error) }
        }
    }

    private func runTest(_ agent: NotificationAgentInfo) {
        guard let client = model.client else { return }
        testing.insert(agent.id)
        Task {
            do {
                let r = try await client.configTest(.notificationAgents, id: agent.id)
                results[agent.id] = r
                toaster.show(r.message.isEmpty ? (r.ok ? "Test notification sent" : "Test failed") : r.message,
                             tone: r.ok ? .success : .error)
            } catch {
                toaster.error(error)
            }
            testing.remove(agent.id)
        }
    }

    private func askDelete(_ agent: NotificationAgentInfo) {
        confirm = FetchConfirm(title: "Delete \(agent.name)?", message: "This notification agent stops firing.") {
            Task {
                guard let client = model.client else { return }
                do {
                    try await client.configDelete(.notificationAgents, id: agent.id)
                    await load()
                } catch { toaster.error(error, title: "Could not delete the agent") }
            }
        }
    }
}
