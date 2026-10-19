import SwiftUI
import FusionhaKit

/// Secrets the current key can't read (web `UnreadableList`): Reset per row,
/// Reset all on top. The sheet gets a snapshot: what you saw is what resets.
struct SecurityUnreadableSection: View {
    let status: SecretsStatus
    let store: SecurityStatusStore
    @State private var pending: SecurityResetBatch?

    var body: some View {
        let n = status.unreadable.count
        SettingsSection {
            SecurityHeroRow(symbol: "exclamationmark.triangle", tone: Theme.miss,
                            title: n == 1 ? "1 secret can’t be read" : "\(SecretsCopy.secrets(n)) can’t be read",
                            sub: "The old key encrypted them. fusionha treats them as not set and never overwrites them on its own. Reset clears each one so you can enter a new value.")
            Button("Reset all (\(n))", systemImage: "arrow.counterclockwise") {
                pending = SecurityResetBatch(items: status.unreadable)
            }
            ForEach(status.unreadable) { item in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.label).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
                        HStack(spacing: 6) {
                            Text(SecretsCopy.kindLabel(item.kind))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.mut)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.panel2, in: Capsule())
                            if SecretsCopy.resetRegenerates(item) {
                                Text("Reset makes a new one").font(.caption).foregroundStyle(Theme.dim)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    Button { pending = SecurityResetBatch(items: [item]) } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(SecretsCopy.resetLabel(item))
                }
            }
        }
        .sheet(item: $pending) { batch in SecurityResetSheet(items: batch.items, store: store) }
    }
}

struct SecurityResetBatch: Identifiable {
    let id = UUID()
    let items: [SecretsUnreadable]
}

/// Confirms resetting exactly the snapshot (web `ResetUnreadableDialog`). On
/// `not_unreadable` the status is refetched and the list narrows to what is
/// still unreadable.
private struct SecurityResetSheet: View {
    let store: SecurityStatusStore
    @Environment(\.dismiss) private var dismiss
    @State private var snapshot: [SecretsUnreadable]
    @State private var stale = false
    @State private var working = false
    @State private var error: Error?

    init(items: [SecretsUnreadable], store: SecurityStatusStore) {
        self.store = store
        _snapshot = State(initialValue: items)
    }

    var body: some View {
        let cleared = snapshot.filter { !SecretsCopy.resetRegenerates($0) }
        let regenerated = snapshot.filter { SecretsCopy.resetRegenerates($0) }
        let n = snapshot.count
        NavigationStack {
            Form {
                Section { Text("Only these change. Every readable secret stays as it is.").foregroundStyle(Theme.mut) }
                if !cleared.isEmpty {
                    Section("Cleared · enter new values afterwards") {
                        ForEach(cleared) { Label($0.label, systemImage: "xmark") }
                    }
                }
                if !regenerated.isEmpty {
                    Section("Regenerated") {
                        ForEach(regenerated) { item in
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.label)
                                    Text(SecretsCopy.resetConsequence(item)).font(.caption).foregroundStyle(Theme.mut)
                                }
                            } icon: { Image(systemName: "arrow.clockwise") }
                        }
                    }
                }
                if snapshot.contains(where: { $0.kind == "virtual_instance" }) {
                    Section {
                        SecurityNote(symbol: "powerplug",
                                     text: "Re-pair Overseerr and Prowlarr with the new instance keys, or their requests and syncs will be refused.")
                    }
                }
                if let error {
                    Section { Text(SecretsErrorCopy.message(for: error)).foregroundStyle(Theme.danger) }
                }
            }
            .navigationTitle(n == 1 ? "Reset 1 unreadable secret?" : "Reset \(n) unreadable secrets?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCancelButton(title: stale && n == 0 ? "Close" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Reset \(n)", systemImage: "arrow.counterclockwise", role: .destructive) { Task { await reset() } }
                        .disabled(n == 0 || working)
                }
            }
        }
    }

    private func reset() async {
        guard let client = store.client else { return }
        working = true
        defer { working = false }
        do {
            let result = try await client.resetUnreadableSecrets(names: snapshot.map(\.name))
            store.apply(result.status)
            dismiss()
        } catch {
            self.error = error
            guard (error as? APIError)?.code == "not_unreadable" else { return }
            stale = true
            await store.load()
            let live = Set((store.status?.unreadable ?? []).map(\.name))
            snapshot = snapshot.filter { live.contains($0.name) }
        }
    }
}
