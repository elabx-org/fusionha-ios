import SwiftUI
import FusionhaKit

/// The Server URL card (web `ServerCard` + `ServerUrlPicker`): test every
/// address Plex reported from fusionha's network → ONE recommended address →
/// "Use this" saves it → a collapsed "Using …" summary. "Not listed? Enter
/// manually" keeps the URL field. Then Verify TLS and Test connection, which
/// checks the SAVED url.
struct PlexServerURLSection: View {
    let plex: PlexServerModel
    @Environment(SettingsStore.self) private var store
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var override: Mode?
    @State private var savingUri: String?

    enum Mode { case pick, manual }

    private var saved: String { store.string("plex_server_url") }
    private var conns: [PlexConnection] { plex.server?.suggestedConnections ?? [] }
    private var ready: Bool { store.loaded && plex.server != nil }
    private var picking: Bool { ready && (override ?? (saved.isEmpty ? Mode.pick : nil)) == .pick && !conns.isEmpty }
    private var showsSummary: Bool { override == nil && !saved.isEmpty }

    var body: some View {
        SettingsSection("Server URL") {
            head
            if ready {
                block
            } else {
                SettingsLoadingRow()
            }
            Toggle(isOn: verifyBinding) {
                FieldLabel(label: "Verify TLS certificate",
                           description: "Turn off only for a server on your network with a self-signed certificate.")
            }
            .tint(Theme.indigo)
            .disabled(plex.savingSetting)
            .settingsField("Verify TLS certificate")
            LabeledContent {
                Button(plex.testing ? "Testing…" : "Test connection") { Task { await plex.test(url: saved) } }
                    .buttonStyle(.web())
                    .disabled(plex.testing || saved.isEmpty)
            } label: {
                FieldLabel(label: "Connection", description: "Checks that the saved URL answers as your Plex server.")
            }
            .settingsField("Connection")
            PlexServerStatusRow(saved: saved, testing: plex.testing,
                                result: plex.testedURL == saved ? plex.testResult : nil, server: plex.server)
        }
        .onChange(of: picking, initial: true) {
            plex.pickerOpen = picking
            if picking { Task { await plex.ensureProbe() } }
        }
    }

    private var head: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("Where fusionha reads your Plex libraries. A local address is best.")
                .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if picking && plex.probePhase != .testing {
                Button("Test addresses again", systemImage: "arrow.clockwise") { Task { await plex.runProbe() } }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(Theme.i2)
            }
        }
    }

    @ViewBuilder
    private var block: some View {
        if showsSummary {
            PlexURLSummary(saved: saved, conns: conns, results: plex.probeResults) { change() }
        } else if override == .manual || !picking {
            PlexManualURLEntry(saved: saved, saving: plex.savingSetting, backLabel: backLabel,
                               lost: plex.server?.librariesLostWithoutUrl ?? 0, libraries: plex.libraries ?? [],
                               onSave: { url in Task { await write(url) } }, onBack: back)
        } else if plex.probePhase == .testing {
            PlexProbeProgress(conns: plex.probe?.results.map(\.connection) ?? conns, results: plex.probeResults)
        } else {
            PlexProbeResults(plex: plex, saved: saved, savingUri: savingUri,
                             onUse: use, onManual: { setMode(.manual) },
                             onCancel: cancelAction)
        }
    }

    private var cancelAction: (() -> Void)? {
        if saved.isEmpty { return nil }
        return { setMode(nil) }
    }

    private var backLabel: String? {
        if !conns.isEmpty { return plex.probe != nil ? "Back to found addresses" : "Cancel" }
        return saved.isEmpty ? nil : "Cancel"
    }

    private var verifyBinding: Binding<Bool> {
        Binding(get: { store.bool("plex_server_verify_tls", true) }, set: { v in
            Task { await plex.saveSetting("plex_server_verify_tls", .bool(v), store: store, errorTitle: "Could not save the setting") }
        })
    }

    private func setMode(_ mode: Mode?) {
        SettingsMotion.perform(motionOff) { override = mode }
    }

    private func change() { setMode(.pick) }

    private func back() {
        if conns.isEmpty { setMode(nil); return }
        setMode(plex.probe != nil || saved.isEmpty ? Mode.pick : nil)
    }

    private func use(_ uri: String) {
        if uri == saved { setMode(nil); return }
        savingUri = uri
        Task {
            if await write(uri) { await plex.test(url: uri) }
            savingUri = nil
        }
    }

    @discardableResult
    private func write(_ url: String) async -> Bool {
        let ok = await plex.saveURL(url, store: store)
        if ok { setMode(nil) }
        return ok
    }
}
