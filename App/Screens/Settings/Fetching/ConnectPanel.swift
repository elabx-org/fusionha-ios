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

// MARK: Kinds and events

private struct AgentKindMeta {
    let kind: NotificationAgentKind
    let label: String
    let sub: String
    let color: Color

    init(_ kind: NotificationAgentKind) {
        self.kind = kind
        switch kind {
        case .discord:
            label = "Discord"; sub = "Post to a Discord channel via an incoming webhook URL."; color = Color(hex: 0x5865F2)
        case .telegram:
            label = "Telegram"; sub = "Send via a bot token to a chat/channel id."; color = Color(hex: 0x29A9EB)
        case .webhook:
            label = "Webhook"; sub = "POST a JSON payload to any generic HTTP endpoint."; color = Theme.edition
        }
    }
}

private struct AgentKindChip: View {
    let meta: AgentKindMeta
    var body: some View {
        Text(meta.label)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(meta.color)
            .padding(.horizontal, 7).padding(.vertical, 1.5)
            .background(meta.color.opacity(0.14), in: Capsule())
            .overlay(Capsule().strokeBorder(meta.color.opacity(0.35)))
            .fixedSize()
    }
}

/// The subscribable library events, in the order the form and list show them.
private let agentEvents: [(key: String, label: String, hint: String)] = [
    ("on_grab", "On grab", "A release is sent to the download client"),
    ("on_import", "On import", "A downloaded file is imported into the library"),
    ("on_upgrade", "On upgrade", "An edition is replaced by a better release"),
    ("on_manual_required", "On manual import required", "A download needs manual review before it can import"),
    ("on_failed", "On download failed", "A grabbed download fails"),
    ("on_request", "On request", "A user submits a new request, or a requested title becomes available"),
]

// MARK: Add / edit

private struct NotificationAgentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsMotionOff) private var motionOff
    let agent: NotificationAgentInfo?
    let onSaved: () async -> Void
    @State private var kind: NotificationAgentKind?

    init(agent: NotificationAgentInfo?, onSaved: @escaping () async -> Void) {
        self.agent = agent
        self.onSaved = onSaved
        _kind = State(initialValue: agent?.agentKind)
    }

    var body: some View {
        ZStack {
            if let kind {
                NotificationAgentForm(kind: kind, agent: agent,
                                      onBack: agent == nil ? { set(nil) } : nil, onSaved: onSaved)
                    .transition(.opacity.combined(with: .offset(y: motionOff ? 0 : 8)))
            } else {
                picker.transition(.opacity.combined(with: .offset(y: motionOff ? 0 : -8)))
            }
        }
    }

    private func set(_ new: NotificationAgentKind?) {
        SettingsMotion.perform(motionOff, SettingsMotion.reveal(0.3)) { kind = new }
    }

    private var picker: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(NotificationAgentKind.allCases) { k in
                        let meta = AgentKindMeta(k)
                        Button { set(k) } label: {
                            HStack(spacing: 12) {
                                Text(String(meta.label.prefix(1)))
                                    .font(.system(size: 15, weight: .heavy))
                                    .foregroundStyle(meta.color)
                                    .frame(width: 40, height: 40)
                                    .background(meta.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(meta.label).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt)
                                    Text(meta.sub).font(.system(size: 12)).foregroundStyle(Theme.mut)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.dim)
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Pick a provider").font(.system(size: 13)).foregroundStyle(Theme.mut).textCase(nil)
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Add notification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .tint(Theme.cyan)
    }
}

private struct NotificationAgentForm: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let kind: NotificationAgentKind
    let agent: NotificationAgentInfo?
    let onBack: (() -> Void)?
    let onSaved: () async -> Void

    @State private var name: String
    @State private var enabled: Bool
    @State private var url = ""
    @State private var token = ""
    @State private var chatId: String
    @State private var events: [String: Bool]
    @State private var result: ConnectionTestResult?
    @State private var testing = false
    @State private var saving = false
    @State private var saveError: String?

    init(kind: NotificationAgentKind, agent: NotificationAgentInfo?, onBack: (() -> Void)?, onSaved: @escaping () async -> Void) {
        self.kind = kind
        self.agent = agent
        self.onBack = onBack
        self.onSaved = onSaved
        _name = State(initialValue: agent?.name ?? AgentKindMeta(kind).label)
        _enabled = State(initialValue: agent?.enabled ?? true)
        _chatId = State(initialValue: agent?.chatId ?? "")
        _events = State(initialValue: agent?.events ?? Dictionary(uniqueKeysWithValues: agentEvents.map { ($0.key, true) }))
    }

    private var meta: AgentKindMeta { AgentKindMeta(kind) }
    private func t(_ s: String) -> String { s.trimmingCharacters(in: .whitespaces) }
    private var hasSecret: Bool {
        kind == .telegram ? (!t(token).isEmpty || agent?.tokenConfigured == true)
            : (!t(url).isEmpty || agent?.urlConfigured == true)
    }
    private var valid: Bool { !t(name).isEmpty && hasSecret && (kind != .telegram || !t(chatId).isEmpty) }
    private var title: String { agent == nil ? "Add \(meta.label) notification" : "Edit \(meta.label) notification" }

    var body: some View {
        FetchFormSheet(title: title, subtitle: meta.sub, saveLabel: "Save notification",
                       canSave: valid && !testing, saving: saving, onCancel: { dismiss() }, onSave: save) {
            SettingsSection("Agent") {
                FetchTextRow(label: "Name", text: $name)
                FetchToggleRow(label: "Enabled", description: "Disabled agents are kept but never fire", isOn: $enabled)
            }
            SettingsSection(meta.label) {
                if kind == .telegram {
                    FetchTextRow(label: "Bot token", text: $token,
                                 prompt: agent?.tokenConfigured == true ? "•••• (unchanged)" : "", secure: true, mono: true)
                    FetchTextRow(label: "Chat ID", text: $chatId, prompt: "e.g. -1001234567890", mono: true,
                                 keyboard: .numbersAndPunctuation)
                } else {
                    FetchTextRow(label: kind == .discord ? "Webhook URL" : "URL", text: $url,
                                 prompt: agent?.urlConfigured == true ? "•••• (unchanged)"
                                    : kind == .discord ? "https://discord.com/api/webhooks/…" : "https://example.com/hook",
                                 secure: true, mono: true, keyboard: .URL)
                }
            }
            SettingsSection("Notify on") {
                ForEach(agentEvents, id: \.key) { event in
                    FetchToggleRow(label: event.label, description: event.hint,
                                   isOn: Binding(get: { events[event.key] ?? false }, set: { events[event.key] = $0 }))
                }
            }
            Section {
                HStack(spacing: 10) {
                    Button { runTest() } label: { Label("Test", systemImage: "bolt.fill") }
                        .buttonStyle(.web())
                        .disabled(!valid || testing || saving)
                    FetchTestResultLine(testing: testing, result: result, okFallback: "Test notification sent")
                    Spacer(minLength: 0)
                }
                if let saveError {
                    Label(saveError, systemImage: "xmark").font(.system(size: 12)).foregroundStyle(Theme.danger)
                }
                if let onBack { Button("‹ Back") { onBack() }.buttonStyle(.web(.ghost)) }
            }
            .listRowBackground(Theme.card)
        }
    }

    private func payload() -> SettingsJSON {
        var b: [String: SettingsJSON] = ["name": .string(t(name)), "kind": .string(kind.rawValue), "enabled": .bool(enabled)]
        for event in agentEvents { b[event.key] = .bool(events[event.key] ?? false) }
        // `settings` stays as stored on edit (this form doesn't own it).
        if agent == nil { b["settings"] = .object([:]) }
        if kind == .telegram {
            if !t(token).isEmpty { b["token"] = .string(t(token)) }
            b["chat_id"] = t(chatId).isEmpty ? .null : .string(t(chatId))
        } else if !t(url).isEmpty {
            b["url"] = .string(t(url))
        }
        return .object(b)
    }

    private func runTest() {
        guard let client = model.client, valid else { return }
        result = nil
        testing = true
        Task {
            do { result = try await client.configTestUnsaved(.notificationAgents, payload()) } catch {
                result = ConnectionTestResult(ok: false, message: error.settingsMessage)
            }
            testing = false
        }
    }

    private func save() {
        guard let client = model.client, valid else { return }
        saving = true
        saveError = nil
        Task {
            do {
                if let agent {
                    try await client.configUpdate(.notificationAgents, id: agent.id, payload())
                } else {
                    try await client.configCreate(.notificationAgents, payload())
                }
                await onSaved()
                dismiss()
            } catch { saveError = error.settingsMessage }
            saving = false
        }
    }
}
