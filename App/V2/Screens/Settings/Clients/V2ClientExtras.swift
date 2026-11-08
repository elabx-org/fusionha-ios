import SwiftUI
import FusionhaKit

/// Under the client cards (mock `extras`): the decypharr stages and the
/// Auto-fix switch as grouped switch rows. Same settings and calls as v1's
/// `DecypharrStagesCard` and `AutoFixSwitchCard`; admin-only, like the API.
struct V2ClientExtras: View {
    @Environment(AppModel.self) private var model
    @Environment(SettingsStore.self) private var store
    @State private var stages: DecypharrStages?
    @State private var error: String?

    private var known: Bool { model.me != nil }
    private var isAdmin: Bool { model.me?.isAdmin == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            V2SettingsGroupHeader(title: "decypharr stages")
            VStack(spacing: 0) {
                V2SettingsToggleRow(title: "Validating",
                                    subtitle: "Turn off if your decypharr skips validation (skip_ffprobe_validation is on). On by default.",
                                    isOn: stageBinding(\.validating))
                V2SettingsHairline()
                V2SettingsToggleRow(title: "Probing",
                                    subtitle: "Turn on if your decypharr probes files after linking them (skip_post_symlink_probe is off). Off by default.",
                                    isOn: stageBinding(\.probing))
            }
            .disabled(!isAdmin || stages == nil)
            .v2CardStyle(padding: 0)
            V2SettingsFootnote(text: isAdmin
                ? "This only changes what the Activity queue’s stage rail shows; nothing is grabbed or imported differently."
                : "Only an admin can change this.")
            if let error { V2SettingsFootnote(text: error, tone: Theme.danger) }

            V2SettingsGroupHeader(title: "Auto-fix")
            V2SettingsToggleRow(title: "Auto-fix confirmed issues",
                                subtitle: "When a report is confirmed, fusionha fixes it itself: it searches for missing episodes, replaces a dead file while keeping the current copy until the new one checks out, and asks Plex to rescan. Turn this off and every fix waits for a person.",
                                isOn: store.boolBinding("issue_autofix_enabled", true))
                .disabled(!known || !isAdmin || !store.loaded)
                .v2CardStyle(padding: 0)
            if known && !isAdmin { V2SettingsFootnote(text: "Only admins can change this.") }
        }
        .task(id: isAdmin) {
            guard isAdmin else { return }
            stages = try? await model.client?.decypharrStages()
        }
    }

    private func stageBinding(_ key: WritableKeyPath<DecypharrStages, Bool>) -> Binding<Bool> {
        Binding(get: { stages?[keyPath: key] ?? false }, set: { save(key, $0) })
    }

    private func save(_ key: WritableKeyPath<DecypharrStages, Bool>, _ on: Bool) {
        guard var next = stages, let client = model.client else { return }
        let previous = next
        next[keyPath: key] = on
        stages = next
        error = nil
        Task {
            do {
                stages = try await client.updateDecypharrStages(next)
            } catch {
                stages = previous
                self.error = ErrorCopy.message(for: error, fallback: "Couldn’t save. Try again.")
            }
        }
    }
}
