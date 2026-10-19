import SwiftUI
import UIKit
import FusionhaKit

// MARK: Mint token

struct MintTokenSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let onMinted: () async -> Void
    @State private var name = ""
    @State private var expires = false
    @State private var expiresOn = Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now
    @State private var minted: String?
    @State private var copied = false
    @State private var saving = false
    @State private var saveError: String?

    var body: some View {
        FetchFormSheet(title: "Mint API token",
                       subtitle: minted == nil ? "A personal token for scripts or external tools to authenticate directly against `/api/v1`." : nil,
                       saveLabel: minted == nil ? "Mint token" : "Done",
                       canSave: minted != nil || !name.trimmingCharacters(in: .whitespaces).isEmpty,
                       saving: saving,
                       onCancel: { dismiss() },
                       onSave: { if minted != nil { dismiss() } else { mint() } }) {
            if let minted {
                SettingsSection(footer: "This is the only time this token is shown — copy it now. If it's lost, revoke it here and mint a new one.") {
                    Text(minted)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Theme.txt)
                        .textSelection(.enabled)
                    Button(copied ? "Copied" : "Copy") {
                        UIPasteboard.general.string = minted
                        copied = true
                    }
                    .buttonStyle(.web())
                    .accessibilityLabel("Copy minted token")
                }
            } else {
                SettingsSection(footer: "Leave the expiry off for a token that never expires.") {
                    FetchTextRow(label: "Name", text: $name, prompt: "CI script")
                    Toggle(isOn: $expires) { FieldLabel(label: "Expires") }.tint(Theme.indigo)
                    if expires {
                        DatePicker("Expires on", selection: $expiresOn, in: Date.now..., displayedComponents: .date)
                            .tint(Theme.indigo)
                    }
                }
                if let saveError {
                    Section { Label(saveError, systemImage: "xmark").font(.system(size: 12)).foregroundStyle(Theme.danger) }
                        .listRowBackground(Theme.card)
                }
            }
        }
        .interactiveDismissDisabled(minted != nil)
    }

    private func mint() {
        guard let client = model.client else { return }
        var expiresAt: String?
        if expires {
            let end = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: expiresOn) ?? expiresOn
            expiresAt = ISO8601DateFormatter().string(from: end)
        }
        saving = true
        saveError = nil
        Task {
            do {
                minted = try await client.mintApiToken(name: name.trimmingCharacters(in: .whitespaces), expiresAt: expiresAt).token
                await onMinted()
            } catch { saveError = error.settingsMessage }
            saving = false
        }
    }
}
