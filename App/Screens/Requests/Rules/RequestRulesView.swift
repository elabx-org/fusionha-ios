import SwiftUI
import FusionhaKit

/// The approver's Rules lane (web A3 `RequestRulesPanel`): approve rules,
/// checked top to bottom (first match wins), then guards (a tripped guard
/// sends the request to a person even when a rule would approve it), the
/// weekly quota card and what was auto-approved in the last 24 hours. Writes
/// need Manage settings; loosening a guard is admin-only (the server says so).
struct RequestRulesView: View {
    @Environment(AppModel.self) private var model
    @State private var rules: [RequestRule] = []
    @State private var roles: [RoleSummary] = []
    @State private var loaded = false
    @State private var editing: RuleEditTarget?
    @State private var deleting: RequestRule?
    @State private var busy: Set<Int> = []

    private var canManage: Bool { model.me?.hasPermission("settings.manage") ?? false }
    private var approve: [RequestRule] { rules.filter { !$0.kind.isGuard } }
    private var guards: [RequestRule] { rules.filter { $0.kind.isGuard } }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Rules").font(Theme.display(26)).foregroundStyle(Theme.txt)
                Spacer()
                Button("Add rule", systemImage: "plus") { editing = .new }
                    .buttonStyle(ActButtonStyle(kind: .primary))
                    .disabled(!canManage)
            }
            if !canManage {
                Label("Needs Manage settings", systemImage: "lock").font(.footnote).foregroundStyle(Theme.mut)
            }
            section("Approve rules · first match wins", note: "Rules are checked top to bottom; the first match wins.") {
                if approve.isEmpty && loaded { empty("No approve rules yet.") }
                ForEach(Array(approve.enumerated()), id: \.element.id) { index, rule in
                    row(rule, first: index == 0, last: index == approve.count - 1)
                }
            }
            section("Guards", note: "Guards win: if a guard trips, the request waits for a person even when a rule would approve it.") {
                if guards.isEmpty && loaded { empty("No guards.") }
                ForEach(guards) { row($0, first: true, last: true) }
            }
            RequestQuotaCard(canManage: canManage)
            RequestAutoApprovedStrip()
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $editing) { target in
            RuleEditorSheet(target: target, roles: roles) { await load() }
        }
        .confirmationDialog("Delete this rule?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible, presenting: deleting) { rule in
            Button("Delete \"\(rule.label)\"", role: .destructive) { Task { await delete(rule) } }
        }
    }

    private func section<C: View>(_ title: String, note: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.system(size: 11, weight: .bold)).tracking(0.8).foregroundStyle(Theme.dim)
            Text(note).font(.footnote).foregroundStyle(Theme.mut).fixedSize(horizontal: false, vertical: true)
            content()
        }
    }

    private func empty(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(Theme.mut).padding(.vertical, 6)
    }

    private func row(_ rule: RequestRule, first: Bool, last: Bool) -> some View {
        let tone = rule.kind.isGuard ? Theme.danger : Theme.done
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: rule.kind.isGuard ? "shield.lefthalf.filled" : "checkmark.seal")
                    .foregroundStyle(tone).frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(rule.label).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        if let role = rule.roleName { Text("Role: \(role)").foregroundStyle(Theme.i2) }
                        Text(rule.firedLine).foregroundStyle(Theme.mut)
                    }
                    .font(.system(size: 12))
                }
                Spacer(minLength: 0)
                Toggle("Enable rule: \(rule.label)", isOn: Binding(get: { rule.enabled }, set: { on in Task { await setEnabled(rule, on) } }))
                    .labelsHidden().tint(Theme.i1)
                    .disabled(!canManage || busy.contains(rule.id))
            }
            if canManage && !rule.locked {
                HStack(spacing: 4) {
                    if !rule.kind.isGuard {
                        iconButton("arrow.up", "Move \"\(rule.label)\" up", disabled: first) { await move(rule, -1) }
                        iconButton("arrow.down", "Move \"\(rule.label)\" down", disabled: last) { await move(rule, 1) }
                    }
                    Spacer()
                    iconButton("pencil", "Edit \"\(rule.label)\"") { editing = .edit(rule) }
                    iconButton("trash", "Delete \"\(rule.label)\"") { deleting = rule }
                }
                .padding(.leading, 32)
            } else if rule.locked {
                Text("A built-in rule can only be turned on or off").font(.caption).foregroundStyle(Theme.dim).padding(.leading, 32)
            }
        }
        .padding(12)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(tone.opacity(0.7)).frame(width: 3).padding(.vertical, 10)
        }
        .opacity(rule.enabled ? 1 : 0.6)
    }

    private func iconButton(_ symbol: String, _ label: String, disabled: Bool = false, _ action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(disabled ? Theme.dim : Theme.txt)
        .disabled(disabled)
        .accessibilityLabel(label)
    }

    // MARK: Actions

    private func load() async {
        guard let client = model.client else { return }
        if let fresh = try? await client.requestRules() { rules = fresh.sorted { $0.position < $1.position } }
        if roles.isEmpty, let r = try? await client.roleSummaries() { roles = r }
        loaded = true
    }

    private func setEnabled(_ rule: RequestRule, _ on: Bool) async {
        await write(rule.id, fallback: "Couldn’t change the rule.") { client in
            _ = try await client.patchRequestRule(id: rule.id, ["enabled": .bool(on)])
        }
    }

    private func move(_ rule: RequestRule, _ dir: Int) async {
        guard let ids = RequestRuleOrder.moved(rules, id: rule.id, by: dir) else { return }
        await write(rule.id, fallback: "Couldn’t change the rule.") { client in
            _ = try await client.reorderRequestRules(ids)
        }
    }

    private func delete(_ rule: RequestRule) async {
        await write(rule.id, fallback: "Couldn’t delete the rule.") { client in
            try await client.deleteRequestRule(id: rule.id)
        }
    }

    private func write(_ id: Int, fallback: String, _ op: (APIClient) async throws -> Void) async {
        guard let client = model.client else { return }
        busy.insert(id)
        defer { busy.remove(id) }
        do {
            try await op(client)
        } catch {
            model.toast(ErrorCopy.message(for: error, fallback: fallback), variant: .error)
        }
        await load()
    }
}

/// What the editor opens on.
enum RuleEditTarget: Identifiable {
    case new
    case edit(RequestRule)
    var id: Int { if case .edit(let r) = self { return r.id }; return -1 }
}
