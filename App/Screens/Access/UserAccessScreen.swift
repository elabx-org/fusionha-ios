import SwiftUI
import FusionhaKit

/// "Manage access — {username}" (web `AccessDialog`): every virtual instance
/// with a toggle. On grants it (`POST /instances/{id}/grants`), off revokes the
/// matching grant (`DELETE /grants/{id}`). Pushed from the user editor; only
/// for non-admins, who see just what they've been granted.
struct UserAccessScreen: View {
    let user: UserAccount
    @Environment(AppModel.self) private var model
    @State private var instances: [VirtualInstance]?
    @State private var grants: [Int: AccessGrant] = [:]
    @State private var working = false
    @State private var loadError: String?
    @State private var toast: CalToast?

    var body: some View {
        Form {
            Section {
                Text("Choose which virtual instances this user can see and use in fusionha.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mut)
                    .listRowBackground(Color.clear)
            }
            if let loadError {
                SettingsLoadingRow(error: loadError)
            } else if let instances {
                Section {
                    if instances.isEmpty {
                        Text("No virtual instances exist yet.").font(.system(size: 13)).foregroundStyle(Theme.mut)
                    }
                    ForEach(instances) { row($0) }
                }
            } else {
                SettingsLoadingRow()
            }
        }
        .navigationTitle("Manage access — \(user.username)")
        .navigationBarTitleDisplayMode(.inline)
        .calToast($toast)
        .task { await load() }
        .refreshable { await load() }
    }

    private func row(_ inst: VirtualInstance) -> some View {
        Toggle(isOn: Binding(
            get: { grants[inst.id] != nil },
            set: { on in Task { await toggle(inst.id, on: on) } })) {
            VStack(alignment: .leading, spacing: 2) {
                Text(inst.instanceName).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt)
                Text("\(Text(inst.slug).font(.system(size: 12, design: .monospaced))) · \(inst.tier.chipLabel)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.mut)
            }
        }
        .tint(Theme.i1)
        .disabled(working)
        .accessibilityLabel("Grant \(user.username) access to \(inst.instanceName)")
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            async let list = client.instances()
            async let access = client.userAccess(userId: user.id)
            let (i, a) = try await (list, access)
            instances = i
            grants = AccessGrant.byInstance(a)
            loadError = nil
        } catch {
            loadError = ErrorCopy.message(for: error, fallback: "Couldn’t load this user’s access.")
        }
    }

    private func toggle(_ instanceId: Int, on: Bool) async {
        guard let client = model.client else { return }
        working = true
        defer { working = false }
        do {
            if on {
                try await client.grantAccess(instanceId: instanceId, userId: user.id)
            } else if let existing = grants[instanceId] {
                try await client.revokeGrant(id: existing.id)
            }
        } catch {
            toast = CalToast(title: "Could not update access",
                             message: (error as? APIError)?.serverMessage ?? error.localizedDescription, isError: true)
        }
        if let access = try? await client.userAccess(userId: user.id) {
            grants = AccessGrant.byInstance(access)
        }
    }
}
