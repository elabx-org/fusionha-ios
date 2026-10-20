import SwiftUI
import FusionhaKit

/// "Move the {label} backend" (web `MoveCredentialDialog`): admin-only re-point
/// of one credential onto another identity. Only the login moves; the source
/// keeps its role, grants and requests.
struct MoveCredentialSheet: View {
    let subject: SignInSubject
    let credential: UserCredential
    let candidates: [UserAccount]
    let onMoved: () async -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var targetId: Int?
    @State private var moving = false
    @State private var toast: CalToast?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Hand this sign-in method to another identity. \(subject.name) keeps every grant, role and request — only the login moves.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.mut)
                        .listRowBackground(Color.clear)
                }
                Section {
                    if candidates.isEmpty {
                        Text("No other identities to move it to.").font(.system(size: 13)).foregroundStyle(Theme.mut)
                    } else {
                        Picker("Target identity", selection: $targetId) {
                            ForEach(candidates) { Text($0.displayName).tag(Int?.some($0.id)) }
                        }
                    }
                }
            }
            .navigationTitle("Move the \(credential.providerLabel) backend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Move backend", systemImage: "arrow.right.circle") { Task { await move() } }
                        .disabled(moving || targetId == nil || candidates.isEmpty)
                }
            }
        }
        .calToast($toast)
        .presentationDetents([.mediumFitting, .large])
        .onAppear { if targetId == nil { targetId = candidates.first?.id } }
    }

    private func move() async {
        guard let client = model.client, let targetId else { return }
        moving = true
        defer { moving = false }
        do {
            try await client.moveCredential(userId: subject.id, credentialId: credential.id, targetUserId: targetId)
            await onMoved()
            dismiss()
        } catch {
            toast = CalToast(title: "Could not move \(credential.providerLabel)",
                             message: (error as? APIError)?.serverMessage ?? error.localizedDescription, isError: true)
        }
    }
}
