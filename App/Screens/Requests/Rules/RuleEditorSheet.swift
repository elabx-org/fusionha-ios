import SwiftUI
import FusionhaKit

/// Add or edit one rule (web `RuleEditor`): the kind, then for approve rules
/// the version and the audience, the rating floor for a rating rule, the
/// sources of a "Watchlists & lists" rule (fusionha 0.4.213), or the
/// free-space floor for a guard (guards apply to every version and everyone).
struct RuleEditorSheet: View {
    let target: RuleEditTarget
    let roles: [RoleSummary]
    let onSaved: () async -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft: RequestRuleDraft
    @State private var saving = false
    @State private var error: String?
    private let before: RequestRuleDraft

    init(target: RuleEditTarget, roles: [RoleSummary], onSaved: @escaping () async -> Void) {
        self.target = target
        self.roles = roles
        self.onSaved = onSaved
        let start: RequestRuleDraft
        if case .edit(let rule) = target { start = RequestRuleDraft(rule) } else { start = RequestRuleDraft() }
        before = start
        _draft = State(initialValue: start)
    }

    private var isNew: Bool { if case .new = target { return true }; return false }

    var body: some View {
        NavigationStack {
            Form {
                if isNew {
                    Picker("Kind", selection: $draft.kind) {
                        ForEach(RequestRule.Kind.editable, id: \.self) { Text($0.label).tag($0) }
                    }
                } else {
                    LabeledContent("Kind", value: draft.kind.label)
                }
                if !draft.kind.isGuard {
                    Picker("Version", selection: $draft.tier) {
                        Text("Every version").tag(QualityTier?.none)
                        Text("HD·1080p").tag(QualityTier?.some(.hd))
                        Text("UHD·4K").tag(QualityTier?.some(.uhd))
                    }
                    Picker("Who", selection: $draft.roleId) {
                        Text("Everyone").tag(Int?.none)
                        ForEach(roles) { Text($0.name).tag(Int?.some($0.id)) }
                    }
                }
                if draft.kind == .watchlistApprove {
                    RuleSourcesSection(draft: $draft, roleName: roles.first(where: { $0.id == draft.roleId })?.name)
                }
                if draft.kind == .approveRating {
                    Stepper(value: $draft.minRating, in: 1...10, step: 0.5) {
                        LabeledContent("TMDB rating at least", value: String(format: "%.1f", draft.minRating))
                    }
                }
                if draft.kind.isGuard {
                    Stepper(value: $draft.minFreeGb, in: 10...20000, step: 50) {
                        LabeledContent("Hold below", value: "\(Int(draft.minFreeGb)) GB free")
                    }
                }
                Section {
                    EmptyView()
                } footer: {
                    Text(draft.kind.isGuard
                         ? "A guard sends a request to a person when the root it would use has less free space than this."
                         : "You can’t create a rule that approves more than you can yourself.")
                }
                if let error {
                    Section { Text(error).foregroundStyle(Theme.danger).font(.footnote) }
                }
            }
            .navigationTitle(isNew ? "Add rule" : (draft.kind.isGuard ? "Edit guard" : "Edit rule"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save rule") { Task { await save() } }.disabled(saving || !draft.isValid)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() async {
        guard let client = model.client else { return }
        saving = true
        defer { saving = false }
        do {
            switch target {
            case .new: _ = try await client.createRequestRule(draft)
            case .edit(let rule): _ = try await client.patchRequestRule(id: rule.id, draft.patchBody(from: before))
            }
            await onSaved()
            dismiss()
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t save the rule.")
        }
    }
}
