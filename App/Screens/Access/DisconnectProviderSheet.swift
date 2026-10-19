import SwiftUI
import FusionhaKit

/// "Disconnect a sign-in provider" (web `DisconnectProviderDialog`): retire a
/// whole backend (Plex) for everyone. Dry run first: who keeps another
/// sign-in, who would be left without one, and what happens to them.
struct DisconnectProviderSheet: View {
    let onDone: () async -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var fallback: DisconnectFallback = .disable
    @State private var preview: DisconnectPreview?
    @State private var working = false
    @State private var error: String?
    private let provider = "plex"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Provider", value: "Plex")
                } footer: {
                    Text("Removes that backend from every identity. Data is never touched, only the sign-in method.")
                }
                Section {
                    if let preview {
                        Text("\(preview.safe) \(preview.safe == 1 ? "person keeps" : "people keep") another sign-in method. No action needed.")
                            .foregroundStyle(Theme.mut)
                        if preview.zeroed > 0 {
                            Text("\(preview.zeroed) \(preview.zeroed == 1 ? "person is" : "people are") Plex-only and would be left with no sign-in method.")
                                .foregroundStyle(Theme.miss)
                        }
                        if preview.refused {
                            Text("Refused: \(preview.blockers.joined(separator: "; "))").foregroundStyle(Theme.danger)
                        }
                    } else {
                        ProgressView()
                    }
                }
                .font(.subheadline)
                Section("For the Plex-only people") {
                    Picker("Fallback", selection: $fallback) {
                        ForEach(DisconnectFallback.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                if let error { Section { Text(error).font(.footnote).foregroundStyle(Theme.danger) } }
            }
            .navigationTitle("Disconnect a sign-in provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Disconnect", systemImage: "minus.circle", role: .destructive) { Task { await run(dryRun: false) } }
                        .disabled(working || preview == nil || preview?.refused == true)
                }
            }
            .task(id: fallback) { await run(dryRun: true) }
        }
    }

    private func run(dryRun: Bool) async {
        guard let client = model.client else { return }
        if dryRun { preview = nil } else { working = true }
        defer { working = false }
        do {
            let out = try await client.disconnectProvider(provider, fallback: fallback, dryRun: dryRun)
            error = nil
            if dryRun { preview = out; return }
            if out.refused {
                let why = out.blockers.joined(separator: "; ")
                model.toast(why.isEmpty ? "The disconnect was refused." : why, title: "Disconnect refused", variant: .error)
                return
            }
            model.toast("That sign-in method no longer works for anyone.", title: "Plex disconnected")
            await onDone()
            dismiss()
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: dryRun ? "Couldn’t preview the disconnect." : "Couldn’t disconnect.")
        }
    }
}
