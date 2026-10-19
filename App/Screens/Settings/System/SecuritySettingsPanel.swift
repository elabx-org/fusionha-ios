import SwiftUI
import WebKit
import FusionhaKit

/// The fusionha app API key (the web's `SecurityPanel.tsx`): redacted until
/// Reveal, then Copy / Hide; Regenerate (after a confirm) shows the new key once.
struct SecuritySettingsPanel: View {
    @Environment(SettingsStore.self) private var store
    @State private var revealed: String?
    @State private var copied = false
    @State private var busy = false
    @State private var confirmRegenerate = false
    @State private var error: String?

    var body: some View {
        SettingsForm(slug: "apikey") {
            SettingsSection {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Image(systemName: "key.horizontal")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.mut)
                            .frame(width: 34, height: 34)
                            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        Text("App API key")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.txt)
                        SettingsStatusPill(text: configured ? "Configured" : "Not set", color: configured ? Theme.done : Theme.dim)
                        Spacer(minLength: 0)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("key").font(.system(size: 12)).foregroundStyle(Theme.mut)
                        if let revealed {
                            Text(revealed)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Theme.txt)
                                .textSelection(.enabled)
                                .transition(.opacity)
                        } else {
                            MonoText("••••••••••••••••")
                        }
                    }
                    Text("Authenticate direct API calls with the `X-Api-Key` header.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.mut)
                    HStack(spacing: 8) {
                        if revealed != nil {
                            Button(copied ? "Copied" : "Copy key") { copy() }
                                .buttonStyle(.web())
                                .accessibilityLabel("Copy app API key")
                            Button("Hide key") { revealed = nil }
                                .buttonStyle(.web(.ghost))
                                .accessibilityLabel("Hide app API key")
                        } else {
                            Button("Reveal key") { Task { await reveal() } }
                                .buttonStyle(.web())
                                .disabled(busy)
                                .accessibilityLabel("Reveal app API key")
                            Button("Regenerate key") { confirmRegenerate = true }
                                .buttonStyle(.web())
                                .disabled(busy)
                                .accessibilityLabel("Regenerate app API key")
                        }
                    }
                    if let error {
                        Text(error).font(.system(size: 12)).foregroundStyle(Theme.danger)
                    }
                }
                .padding(.vertical, 6)
                .settingsReveal(delay: 0.06)
                .settingsField("App API key")
            }
        }
        .confirmationDialog("Regenerate the app API key?", isPresented: $confirmRegenerate, titleVisibility: .visible) {
            Button("Regenerate key", role: .destructive) { Task { await regenerate() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Anything using the current key stops working until you give it the new one.")
        }
    }

    private var configured: Bool { store.bool("app_key_configured") }

    private func copy() {
        guard let revealed else { return }
        UIPasteboard.general.string = revealed
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            copied = false
        }
    }

    private func reveal() async {
        guard let client = store.client else { return }
        busy = true
        defer { busy = false }
        do {
            let key = try await client.revealAppApiKey()
            withAnimation(.easeOut(duration: 0.2)) { revealed = key }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func regenerate() async {
        guard let client = store.client else { return }
        busy = true
        defer { busy = false }
        do {
            revealed = try await client.regenerateAppApiKey()
            error = nil
            await store.load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// A small rounded status pill (the web's `.pill`).
struct SettingsStatusPill: View {
    let text: String
    var color: Color = Theme.done

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .frame(height: 22)
            .background(color.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.32)))
    }
}
