import SwiftUI
import FusionhaKit

/// The newest "decypharr import rules fired" stamp across every client
/// (web `ImportRulesNote`), shown once above the list on a working wash.
struct ImportRulesNoteView: View {
    let clients: [DownloadClientInfo]

    var body: some View {
        if let latest = ImportRulesNote.latest(clients) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.grab)
                    .padding(.top, 1)
                    .accessibilityHidden(true)
                (Text("decypharr import rules last fired ")
                    + Text(ImportRulesNote.seenAgo(latest)).bold().foregroundStyle(Theme.txt)
                    + Text(". It is informational only: file checks don’t depend on it."))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .actWash(Theme.grab, radius: 12, base: Theme.panel)
            .padding(.bottom, 12)
            .accessibilityElement(children: .combine)
        }
    }
}

/// The "Fixes" card (web `AutoFixSwitch`): the one global auto-fix setting.
/// Saves `issue_autofix_enabled` alone; only an admin can change it.
struct AutoFixSwitchCard: View {
    @Environment(SettingsStore.self) private var store
    @Environment(AppModel.self) private var model

    private var known: Bool { model.me != nil }
    private var isAdmin: Bool { model.me?.isAdmin ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fixes")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.txt)
                .accessibilityAddTraits(.isHeader)
            Toggle(isOn: store.boolBinding("issue_autofix_enabled", true)) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Auto-fix confirmed issues")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Theme.txt)
                    Text("When a report is confirmed, fusionha fixes it itself: it searches for missing episodes, replaces a dead file while keeping the current copy until the new one checks out, and asks Plex to rescan. Turn this off and every fix waits for a person.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Theme.indigo)
            .disabled(!known || !isAdmin || !store.loaded)
            if known && !isAdmin {
                Label("Only admins can change this.", systemImage: "lock")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.mut)
            }
        }
        .fetchCard()
    }
}
