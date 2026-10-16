import SwiftUI
import FusionhaKit

/// The key's status (web `KeyStatusCard`): first-run / out-of-date banners,
/// the hero, progress, fingerprint, source, created, and the key actions.
struct SecurityKeySections: View {
    let status: SecretsStatus
    @Bindable var store: SecurityStatusStore
    @State private var recoveryOpen = false
    @State private var rotateOpen = false
    @State private var resuming = false
    @State private var resumeError: String?

    var body: some View {
        if let banner {
            SettingsSection {
                SecurityHeroRow(symbol: banner.symbol, tone: Theme.i1, title: banner.title, sub: banner.sub)
                Button("Download", systemImage: "arrow.down.circle") { openRecovery() }
            }
        }
        SettingsSection {
            SecurityHeroRow(symbol: status.hero.icon.symbol, tone: status.tone.color,
                            title: status.hero.title, sub: status.hero.sub)
            if let prog = status.progress { progressRow(prog) }
            SettingValueRow(label: "Key fingerprint") {
                MonoText(SecretsCopy.groupFingerprint(status.keyFingerprint), color: Theme.txt)
            }
            SettingValueRow(label: "Source", description: status.keySource == "file" ? status.keyPath : nil) {
                Text(status.sourceLabel).font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            }
            SettingValueRow(label: "Created") {
                Text(SecretsCopy.stamp(status.keyCreatedAt)).font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            }
        }
        SettingsSection(footer: [status.recoveryBlockedReason, status.rotateBlockedReason, resumeError]
            .compactMap { $0 }.first) {
            Button("Download recovery key", systemImage: "arrow.down.circle") { openRecovery() }
                .disabled(status.recoveryBlockedReason != nil)
            Button("Rotate key", systemImage: "arrow.clockwise") { rotateOpen = true }
                .disabled(status.rotateBlockedReason != nil)
            if status.rotationStalled {
                Button(resuming ? "Resuming…" : "Resume rotation", systemImage: "arrow.clockwise") {
                    Task { await resume() }
                }
                .disabled(resuming)
            }
        }
        .sheet(isPresented: $recoveryOpen) { SecurityRecoveryKeySheet(keyPath: status.keyPath, store: store) }
        .sheet(isPresented: $rotateOpen) {
            SecurityRotateSheet(secretCount: status.encryptedCount, keyPath: status.keyPath, store: store)
        }
    }

    private struct Banner {
        let symbol: String
        let title: String
        let sub: String
    }

    private var banner: Banner? {
        if status.firstRun {
            return Banner(symbol: "sparkles", title: "fusionha created an encryption key.",
                          sub: "Download the recovery key now and keep it somewhere other than this server. Without it, a backup restored on a new machine can’t read your secrets.")
        }
        if store.rotationFinished {
            return Banner(symbol: "checkmark.circle", title: "Key rotated. Download the new recovery key.",
                          sub: "A recovery key you downloaded before can’t unlock what fusionha stores now.")
        }
        if status.recoveryKeyStale == true, status.state == "ok" {
            return Banner(symbol: "exclamationmark.triangle", title: "Your saved recovery key is out of date.",
                          sub: "The key changed, so a recovery key you downloaded before can’t unlock what fusionha stores now. Download the new one and replace the old copy.")
        }
        return nil
    }

    private func progressRow(_ prog: SecretsProgressInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(prog.label).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                Spacer()
                Text("\(prog.done) of \(prog.total)").font(.system(size: 12).monospacedDigit()).foregroundStyle(Theme.mut)
            }
            ProgressView(value: prog.fraction).tint(Theme.i1)
                .accessibilityLabel(prog.label)
        }
        .padding(.vertical, 4)
    }

    private func openRecovery() {
        store.rotationFinished = false
        recoveryOpen = true
    }

    private func resume() async {
        guard let client = store.client else { return }
        resuming = true
        defer { resuming = false }
        do {
            _ = try await client.resumeSecretsRotation()
            resumeError = nil
        } catch {
            resumeError = SecretsErrorCopy.message(for: error)
        }
        await store.load()
    }
}
