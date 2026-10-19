import SwiftUI
import FusionhaKit

/// Settings › Requests › Rules (web A3 `RequestRulesPanel`): the standard
/// panel header, the web's lead line, Add rule, the approve rules (checked
/// top to bottom, first match wins), the guards (only when there are any)
/// with their note, the weekly quota card, the source checks and what was
/// auto-approved in the last day. Writes need Manage settings; loosening a
/// guard is admin-only.
struct RequestRulesView: View {
    @Environment(AppModel.self) private var model
    @State private var rules: [RequestRule] = []
    @State private var roles: [RoleSummary] = []
    @State private var guardRoots: [GuardRoot] = []
    @State private var loaded = false
    @State private var editing: RuleEditTarget?
    @State private var deleting: RequestRule?
    @State private var busy: Set<Int> = []

    private var canManage: Bool { model.me?.hasPermission("settings.manage") ?? false }
    private var isAdmin: Bool { model.me?.isAdmin ?? false }
    private var approve: [RequestRule] { rules.filter { !$0.kind.isGuard } }
    private var guards: [RequestRule] { rules.filter { $0.kind.isGuard } }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsPanelHeading(slug: "requestrules")
            Text("Rules approve requests without a person. Order matters; the first matching rule wins. Guards win: if a guard trips, the request waits for a person even when a rule would approve it.")
                .font(.system(size: 14)).foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
            if !canManage { readOnlyBanner }
            GatedTip(reason: canManage ? nil : RuleRowCopy.needsManage) {
                Button("Add rule", systemImage: "plus") { editing = .new }
                    .buttonStyle(ActButtonStyle(kind: .primary))
            }
            ruleLists
            RequestQuotaCard(canManage: canManage)
            SourceChecksCard()
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

    @ViewBuilder
    private var ruleLists: some View {
        if rules.isEmpty && loaded {
            Text("No rules yet. Requests wait for an approver unless a user has their own auto-approve.")
                .font(.system(size: 14)).foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
        }
        if !approve.isEmpty {
            section("Approve rules · first match wins") {
                ForEach(Array(approve.enumerated()), id: \.element.id) { i, rule in row(rule, index: i, count: approve.count) }
            }
        }
        if !guards.isEmpty {
            section("Guards") {
                ForEach(Array(guards.enumerated()), id: \.element.id) { i, rule in row(rule, index: i, count: guards.count) }
                Label("Guards win. When a guard holds a request, no approve rule can approve it; the request waits for a person.",
                      systemImage: "info.circle")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var readOnlyBanner: some View {
        Label {
            Text("You can approve requests but not change settings. Rules, guards and quotas are read-only. Tooltips say ")
                + Text("Needs Manage settings").bold() + Text(".")
        } icon: {
            Image(systemName: "lock")
        }
        .font(.system(size: 13)).foregroundStyle(Theme.mut)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.system(size: 11, weight: .bold)).tracking(0.8).foregroundStyle(Theme.dim)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func row(_ rule: RequestRule, index: Int, count: Int) -> some View {
        RequestRuleRow(rule: rule, index: index, count: count,
                       reasons: RuleRowCopy.reasons(rule, canManage: canManage, isAdmin: isAdmin),
                       roots: GuardRoot.roots(guardRoots, for: rule.tier), busy: busy.contains(rule.id),
                       onToggle: { on in Task { await setEnabled(rule, on) } },
                       onMove: { dir in Task { await move(rule, dir) } },
                       onEdit: { editing = .edit(rule) },
                       onDelete: { deleting = rule })
    }

    // MARK: Actions

    private func load() async {
        guard let client = model.client else { return }
        if let fresh = try? await client.requestRules() { rules = fresh.sorted { $0.position < $1.position } }
        if roles.isEmpty, let r = try? await client.roleSummaries() { roles = r }
        if let roots = try? await client.rootFolders(), let slots = try? await client.addDefaults() {
            guardRoots = GuardRoot.from(roots: roots, slots: slots)
        }
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
