import SwiftUI
import FusionhaKit

/// Connect › "Registered by external tools": the native Add / Edit
/// Notification — Webhook sheet (`ArrWebhookEditDialog.tsx`). Add picks the
/// virtual instance; Edit fixes it and adds a live Test and Delete. The
/// password never round-trips: blank keeps the stored secret.
struct ArrWebhookEditSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let webhook: ArrWebhookGroup.Webhook?
    /// Shown for the fixed instance when editing.
    var instanceLabel: String?
    let onSaved: () async -> Void

    @State private var draft: ArrWebhookDraft
    @State private var instances: [VirtualInstance] = []
    @State private var authOpen: Bool
    @State private var mappingsOpen: Bool
    @State private var saving = false
    @State private var testing = false
    @State private var deleting = false
    @State private var confirmingDelete = false
    @State private var result: ConnectionTestResult?
    @State private var saveError: String?

    init(webhook: ArrWebhookGroup.Webhook?, instanceLabel: String? = nil, onSaved: @escaping () async -> Void) {
        self.webhook = webhook
        self.instanceLabel = instanceLabel
        self.onSaved = onSaved
        let draft = ArrWebhookDraft(webhook: webhook)
        _draft = State(initialValue: draft)
        _authOpen = State(initialValue: draft.authStartsOpen)
        _mappingsOpen = State(initialValue: !draft.pathMappings.isEmpty)
    }

    var body: some View {
        FetchFormSheet(title: webhook == nil ? "Add Notification — Webhook" : "Edit Notification — Webhook",
                       subtitle: "Send arr-shaped webhook events (Grab, Import, Upgrade, …) to an external URL.",
                       canSave: draft.isValid, saving: saving,
                       onCancel: { dismiss() }, onSave: save) {
            SettingsSection {
                instanceRow
                FetchTextRow(label: "Name", text: $draft.name)
                endpoint
            }
            SettingsSection("Trigger on") {
                ForEach(ArrWebhookTriggerGroup.allCases, id: \.self) { group in
                    ArrWebhookTriggerGroupView(group: group, draft: $draft)
                }
            }
            SettingsSection {
                DisclosureGroup("Auth & headers (optional)", isExpanded: $authOpen) {
                    FetchTextRow(label: "Username", text: $draft.username, prompt: "optional")
                    FetchTextRow(label: "Password", text: $draft.password,
                                 prompt: draft.passwordConfigured ? "•••• (unchanged)" : "optional",
                                 secure: true, mono: true)
                    ArrWebhookHeaderRows(rows: $draft.headers)
                }
                DisclosureGroup("Path mappings (optional)", isExpanded: $mappingsOpen) {
                    ArrWebhookPathMappingRows(mappings: $draft.pathMappings)
                }
            }
            if webhook != nil { testSection }
            if let saveError {
                Section { Label(saveError, systemImage: "xmark").font(.system(size: 12)).foregroundStyle(Theme.danger) }
                    .listRowBackground(Theme.card)
            }
        }
        .task { if webhook == nil { await loadInstances() } }
        .confirmationDialog("Delete this webhook?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete() }
        } message: {
            Text("The external tool may re-register it on its next sync.")
        }
    }

    @ViewBuilder
    private var instanceRow: some View {
        if let webhook {
            LabeledContent {
                Text(instanceLabel ?? webhook.instanceId.map { "Instance #\($0)" } ?? "—")
                    .font(.system(size: 13)).foregroundStyle(Theme.mut)
            } label: {
                Text("Virtual instance").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
            }
        } else {
            Picker(selection: $draft.instanceId) {
                Text("Select an instance").tag(Int?.none)
                ForEach(instances) { instance in
                    Text(instance.instanceName).tag(Int?.some(instance.id))
                }
            } label: {
                Text("Virtual instance").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
            }
            .pickerStyle(.menu)
            .tint(Theme.mut)
        }
    }

    private var endpoint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Endpoint").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
            Picker("HTTP method", selection: $draft.method) {
                Text("POST").tag(1)
                Text("PUT").tag(2)
            }
            .pickerStyle(.segmented)
            .fixedSize()
            TextField("https://example.com/hook", text: $draft.url)
                .font(.system(size: 14, design: .monospaced))
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(Theme.txt)
        }
    }

    private var testSection: some View {
        SettingsSection(footer: "Test probes the saved webhook, so save changes first.") {
            HStack(spacing: 12) {
                Button("Test", systemImage: "bolt") { runTest() }
                    .buttonStyle(.web())
                    .disabled(testing || saving)
                FetchTestResultLine(testing: testing, result: result, okFallback: "Test notification sent")
                Spacer(minLength: 0)
            }
            Button(deleting ? "Deleting…" : "Delete webhook", role: .destructive) { confirmingDelete = true }
                .disabled(deleting)
        }
    }

    // MARK: Actions

    private func loadInstances() async {
        instances = (try? await model.client?.instances()) ?? []
    }

    private func save() {
        guard let client = model.client, draft.isValid else { return }
        saving = true
        saveError = nil
        Task {
            do {
                if let webhook {
                    try await client.updateArrWebhook(id: webhook.id, draft.body)
                } else {
                    try await client.createArrWebhook(draft.body)
                }
                await onSaved()
                dismiss()
            } catch { saveError = error.settingsMessage }
            saving = false
        }
    }

    private func runTest() {
        guard let client = model.client, let webhook else { return }
        result = nil
        testing = true
        Task {
            do {
                result = try await client.testArrWebhook(id: webhook.id)
            } catch {
                result = ConnectionTestResult(ok: false, message: error.settingsMessage)
            }
            testing = false
        }
    }

    private func delete() {
        guard let client = model.client, let webhook else { return }
        deleting = true
        Task {
            do {
                try await client.deleteArrWebhook(id: webhook.id)
                await onSaved()
                dismiss()
            } catch { saveError = error.settingsMessage }
            deleting = false
        }
    }
}
