import SwiftUI
import FusionhaKit

/// "N likely duplicates found" (web `UsersPanel` duplicates banner): the
/// pairs, why, and Review & merge for a full admin. A wash, never a border.
struct UsersDuplicatesBanner: View {
    let groups: [DuplicateGroup]
    let canMerge: Bool
    let review: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "arrow.triangle.merge")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.miss)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(groups.count) likely duplicate\(groups.count == 1 ? "" : "s") found")
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt)
                    Text("\(UsersRoster.duplicatesLine(groups)) — probably the same person signed in two ways.")
                        .font(.system(size: 12)).foregroundStyle(Theme.mut)
                }
            }
            if canMerge {
                Button("Review & merge", action: review)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.i1)
                    .foregroundStyle(Theme.onAccent)
                    .controlSize(.small)
                    .padding(.leading, 26)
            } else {
                Text("Ask an admin to merge these").font(.system(size: 12)).foregroundStyle(Theme.mut)
                    .padding(.leading, 26)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .actWash(Theme.miss, radius: 12)
    }
}

/// "Collapse duplicate identity" (web `MergeDialog`): pick the identity to
/// keep, read the dry run's effective result, then Confirm merge. One pair at
/// a time; a refused merge shows its blockers and can't be confirmed.
struct MergeUsersSheet: View {
    let group: DuplicateGroup
    let onDone: () async -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var survivorId: Int?
    @State private var preview: MergePreview?
    @State private var working = false
    @State private var error: String?

    private var pair: [DuplicateMember] { Array(group.members.prefix(2)) }
    private var survivor: DuplicateMember? { pair.first { $0.id == survivorId } }
    private var loserId: Int? { pair.first { $0.id != survivorId }?.id }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Keep this identity", selection: $survivorId) {
                        ForEach(pair) { m in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.username + (m.isAdmin ? " · Admin" : ""))
                                Text("\(m.authProvider) sign-in").font(.caption).foregroundStyle(Theme.mut)
                            }
                            .tag(Int?.some(m.id))
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Keep this identity")
                } footer: {
                    Text("Keep one identity; move the other’s credentials, requests and issues onto it, then retire it. One-time, never repeats.")
                }
                result
                if let error { Section { Text(error).font(.footnote).foregroundStyle(Theme.danger) } }
            }
            .navigationTitle("Collapse duplicate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(working ? "Merging…" : "Confirm merge") { Task { await run(dryRun: false) } }
                        .disabled(working || preview == nil || preview?.refused == true)
                }
            }
            .task(id: survivorId) {
                if survivorId == nil { survivorId = UsersRoster.defaultSurvivor(pair); return }
                await run(dryRun: true)
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder private var result: some View {
        if let preview, preview.refused {
            Section { Text("Refused: \(preview.blockers.joined(separator: "; "))").foregroundStyle(Theme.danger) }
        } else if let preview {
            Section {
                LabeledContent("Resulting role", value: preview.roleLine)
                LabeledContent("Credentials re-pointed", value: "\(preview.credentialsRepointed)")
                LabeledContent("Requests re-pointed / merged", value: "\(preview.requestsRepointed) / \(preview.requestsMerged)")
                LabeledContent("Issues re-pointed", value: "\(preview.issuesRepointed)")
                LabeledContent("Sessions ended", value: "\(preview.sessionsDeleted)")
                LabeledContent("Duplicate identity", value: "tombstoned (kept for audit)")
            } header: {
                Text("Effective result · Dry run")
            }
        } else {
            Section { ProgressView() }
        }
    }

    private func run(dryRun: Bool) async {
        guard let client = model.client, let survivor = survivorId, let loser = loserId else { return }
        if dryRun { preview = nil } else { working = true }
        defer { working = false }
        do {
            let out = try await client.mergeUsers(survivor: survivor, loser: loser, dryRun: dryRun)
            error = nil
            if dryRun { preview = out; return }
            if out.refused {
                model.toast(out.blockers.joined(separator: "; ").isEmpty ? "The merge was refused." : out.blockers.joined(separator: "; "),
                            title: "Merge refused", variant: .error)
                return
            }
            model.toast("\(self.survivor?.username ?? "The kept identity") now owns every credential, request and issue from the duplicate.",
                        title: "Identities merged")
            await onDone()
            dismiss()
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: dryRun ? "Couldn’t preview the merge." : "Couldn’t merge.")
        }
    }
}
