import SwiftUI
import FusionhaKit

/// Settings › Requests › Guardrails (web A9 `GuardrailsPanel`): the Auto-fix
/// kill switch, what the sweep did in the last 30 days, the four limits and
/// what is paused. Every control is admin-only on the server; the statistics
/// and the paused list come from an admin-only endpoint.
struct GuardrailsSettingsPanel: View {
    @Environment(SettingsStore.self) private var store
    @Environment(AppModel.self) private var model
    @State private var stats: AutofixStats?
    @State private var statsError = false

    private var isAdmin: Bool { model.me?.isAdmin ?? false }

    var body: some View {
        let on = store.bool("issue_autofix_enabled", true)
        SettingsForm(slug: "guardrails") {
            Section {
                SettingToggle(key: "issue_autofix_enabled", label: "Auto-fix confirmed issues",
                              description: on
                                ? "On. When decypharr proves a reported file is dead, fusionha replaces it, keeping the current copy until the new one checks out. Nothing acts on “unknown”, “degraded” or an error."
                                : "Off. Reports still get checked, but every confirmed problem goes to an admin. A fix already running stops on the next maintenance pass (within 5 minutes). Re-grab and “Find a release” for a language fix are refused while it’s off.",
                              fallback: true)
                    .disabled(!isAdmin)
                if !isAdmin {
                    Text("Only an admin can change this. Fix statistics and paused fixes are shown to admins only.")
                        .font(.footnote).foregroundStyle(Theme.mut)
                }
            }
            if isAdmin { statsSection }
            Section("Limits") {
                ForEach(GuardrailLimit.all) { limit in limitRow(limit) }
            }
            if isAdmin { pausedSection }
        }
        .task {
            guard isAdmin, let client = model.client else { return }
            do { stats = try await client.autofixStats(days: 30) } catch { statsError = true }
        }
    }

    private func limitRow(_ limit: GuardrailLimit) -> some View {
        let value = store.int(limit.key, limit.fallback)
        return Stepper {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(limit.title).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(limit.unit(value)).font(.subheadline.monospacedDigit()).foregroundStyle(Theme.mut)
                }
                Text(limit.sub).font(.caption).foregroundStyle(Theme.mut)
            }
        } onIncrement: {
            store.save(limit.key, .number(Double(min(limit.range.upperBound, value + 1))))
        } onDecrement: {
            store.save(limit.key, .number(Double(max(limit.range.lowerBound, value - 1))))
        }
        .disabled(!isAdmin)
        .settingsField(limit.title)
    }

    @ViewBuilder private var statsSection: some View {
        Section("Last 30 days") {
            if let s = stats {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow { tile("Fixes tried", s.attempts, "started"); tile("Fixed", s.fixed, "swapped in") }
                    GridRow { tile("Waiting on an admin", s.waiting, "new copy held"); tile("Failed", s.failed, "given up") }
                }
                let none = s.fixed + s.waiting + s.failed == 0
                Text(none ? "No automatic fixes in the last \(s.days) days."
                     : "Fixed \(s.fixed) · waiting on an admin \(s.waiting) · failed \(s.failed)"
                        + (s.successRate.map { " · \(Int(($0 * 100).rounded()))% of finished fixes worked" } ?? "") + ".")
                    .font(.footnote).foregroundStyle(Theme.mut)
                Text("Counts automatic fixes only: an admin’s Use new copy or Re-grab isn’t counted as fixed.")
                    .font(.caption).foregroundStyle(Theme.dim)
            } else {
                Text(statsError ? "Could not load fix statistics." : "Loading fix statistics…").foregroundStyle(Theme.mut)
            }
        }
    }

    private func tile(_ label: String, _ n: Int, _ hint: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(n)").font(Theme.display(26)).foregroundStyle(Theme.txt)
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(Theme.txt)
            Text(hint).font(.caption2).foregroundStyle(Theme.mut)
        }
    }

    @ViewBuilder private var pausedSection: some View {
        Section {
            if let paused = stats?.paused {
                if paused.isEmpty {
                    Text("Nothing is paused. Auto-fix is free to act on every confirmed report.").foregroundStyle(Theme.mut)
                }
                ForEach(paused) { p in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(p.line).font(.subheadline.weight(.semibold))
                        Text((ServerTime.parse(p.pausedAt).map { "Paused \($0.formatted(.relative(presentation: .named)))" } ?? "Paused")
                             + " · " + p.failuresLine)
                            .font(.caption).foregroundStyle(Theme.miss)
                    }
                }
            }
        } header: {
            Text("Paused · \(stats?.paused.count ?? 0)")
        } footer: {
            Text("A pause clears when an admin resolves the report or re-grabs it from the issue’s thread.")
        }
    }
}

/// Settings › Quality › Blocklist (web `ReleaseGroupsPanel`): release groups
/// you never want grabbed, for one title or everywhere. Single releases live
/// on Activity › Blocklist.
struct ReleaseGroupBlocklistPanel: View {
    @Environment(AppModel.self) private var model
    @State private var blocks: [ReleaseGroupBlock]?
    @State private var error: String?
    @State private var newGroup = ""
    @State private var adding = false

    var body: some View {
        SettingsForm(slug: "blocklist") {
            Section {
                TextField("Release group, e.g. FAKEUHD", text: $newGroup)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button(adding ? "Adding…" : "Block everywhere", systemImage: "nosign") { Task { await add() } }
                    .disabled(adding || newGroup.trimmingCharacters(in: .whitespaces).isEmpty)
            } header: {
                Text("Add a group")
            } footer: {
                Text("Blocks for one title are added from a held download’s Block release group prompt.")
            }
            if let error {
                SettingsLoadingRow(error: error)
            } else if let blocks {
                let global = blocks.filter { $0.scope == "global" }
                let items = blocks.filter { $0.scope != "global" }
                list("Everywhere", global)
                list("For one title", items)
            } else {
                SettingsLoadingRow()
            }
        }
        .task { await load() }
    }

    private func list(_ title: String, _ rows: [ReleaseGroupBlock]) -> some View {
        Section(title) {
            if rows.isEmpty { Text("None.").foregroundStyle(Theme.dim) }
            ForEach(rows) { b in
                VStack(alignment: .leading, spacing: 2) {
                    Text(b.group).font(.system(size: 15, weight: .semibold, design: .monospaced))
                    Text([b.itemTitle, b.reason == "mislabeled_resolution" ? "fake resolution" : "manual", b.createdBy.map { "by \($0)" }, b.note]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(Theme.mut)
                }
                .swipeActions {
                    Button("Unblock", systemImage: "trash", role: .destructive) { Task { await remove(b) } }
                }
            }
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        do { blocks = try await client.releaseGroupBlocks(); error = nil } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t load the blocklist.")
        }
    }

    private func add() async {
        guard let client = model.client else { return }
        adding = true
        defer { adding = false }
        do {
            _ = try await client.addReleaseGroupBlock(newGroup.trimmingCharacters(in: .whitespaces), mediaItemId: nil, note: nil)
            newGroup = ""
            await load()
        } catch {
            model.toast(ErrorCopy.message(for: error), title: "Couldn’t block the group", variant: .error)
        }
    }

    private func remove(_ b: ReleaseGroupBlock) async {
        guard let client = model.client else { return }
        do { try await client.deleteReleaseGroupBlock(id: b.id); await load() } catch {
            model.toast(ErrorCopy.message(for: error), title: "Couldn’t unblock", variant: .error)
        }
    }
}
