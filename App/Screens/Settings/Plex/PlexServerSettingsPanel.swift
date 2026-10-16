import SwiftUI
import FusionhaKit

/// Settings › Access › Plex server (web `PlexServerPanel`): health warnings,
/// the Plex Media Server connection, the "4K Plex libraries" map with its
/// detection evidence, and Plex-derived UHD·4K access (sync, who gets 4K,
/// preview + acknowledge). Admin-only, like the `/plex/*` endpoints.
struct PlexServerSettingsPanel: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        if let me = app.me, !me.isAdmin {
            SettingsForm(slug: "plexserver") {
                Section {
                    Text("Only an administrator can manage the Plex server connection.")
                        .font(.system(size: 13)).foregroundStyle(Theme.mut)
                }
                .listRowBackground(Theme.card)
            }
        } else {
            PlexServerPanelContent(app: app)
        }
    }
}

private struct PlexServerPanelContent: View {
    @State private var plex: PlexServerModel
    @Environment(SettingsStore.self) private var store
    @Environment(\.settingsMotionOff) private var settingsMotionOff
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(app: AppModel) {
        _plex = State(initialValue: PlexServerModel(app: app))
    }

    var body: some View {
        SettingsForm(slug: "plexserver") {
            if let error = plex.loadError, plex.server == nil {
                Section { SettingsLoadingRow(error: error) }
            } else {
                PlexWarningsSection(plex: plex)
                PlexServerURLSection(plex: plex)
                PlexLibrariesSection(plex: plex)
                PlexAccessSection(plex: plex)
            }
        }
        .task {
            plex.motionOff = settingsMotionOff || reduceMotion
            if !store.loaded { await store.load() }
            await plex.reload()
        }
        .refreshable { await plex.reload() }
    }
}

/// The panel's top warning stack: the backend's static health warnings, most urgent first.
private struct PlexWarningsSection: View {
    let plex: PlexServerModel

    var body: some View {
        if let p = plex.preview, !p.warnings.isEmpty {
            let last = PlexSyncStatus.shortAgo(p.lastSyncedAt)
            Section {
                ForEach(PlexSyncStatus.warningNotes(p.warnings, lastSync: last)) { n in
                    PlexNote(color: n.neutral ? Theme.dim : Theme.stuck,
                             symbol: n.neutral ? "clock" : "exclamationmark.triangle",
                             title: n.title, text: n.sub)
                }
            }
            .listRowBackground(Theme.card)
        }
    }
}
