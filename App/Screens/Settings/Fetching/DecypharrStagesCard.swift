import SwiftUI
import FusionhaKit

/// Settings › Download Clients: which optional decypharr steps the Activity
/// queue's stage rail draws (`GET/PUT /api/v1/settings/decypharr-stages`,
/// fusionha 0.4.189; the web's `DecypharrStagesCard`). decypharr doesn't report
/// its own config, so these mirror it. Admin-only, like the API.
struct DecypharrStagesCard: View {
    @Environment(AppModel.self) private var model
    @State private var stages: DecypharrStages?
    @State private var error: String?

    private var isAdmin: Bool { model.me?.isAdmin == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("decypharr stages")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.txt)
            row(\.probing, "decypharr runs a probing step",
                "Turn on if your decypharr probes files after linking them (skip_post_symlink_probe is off). Probing is off by default.")
            row(\.validating, "decypharr runs a validating step",
                "Turn off if your decypharr skips validation (skip_ffprobe_validation is on). Validating is on by default.")
            Text(isAdmin ? "This only changes what the Activity queue’s stage rail shows; nothing is grabbed or imported differently."
                         : "Only an admin can change this.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.dim)
            if let error {
                Text(error).font(.system(size: 12.5)).foregroundStyle(Theme.danger)
            }
        }
        .fetchCard()
        .task(id: isAdmin) {
            guard isAdmin else { return }
            stages = try? await model.client?.decypharrStages()
        }
    }

    private func row(_ key: WritableKeyPath<DecypharrStages, Bool>, _ label: String, _ help: String) -> some View {
        Toggle(isOn: Binding(get: { stages?[keyPath: key] ?? false },
                             set: { save(key, $0) })) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.txt)
                Text(help).font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            }
        }
        .tint(Theme.indigo)
        .disabled(!isAdmin || stages == nil)
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
