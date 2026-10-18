import SwiftUI
import FusionhaKit

/// The "Watchlists & lists" rule's Sources (web `RuleSourcesField` +
/// `WatchlistRuleFields`): five toggles (at least one), what the rule
/// matches, and the sentence it reads as.
struct RuleSourcesSection: View {
    @Binding var draft: RequestRuleDraft
    let roleName: String?

    var body: some View {
        Section {
            ForEach(RuleSource.allCases, id: \.self) { source in
                Toggle(source.label, isOn: binding(source)).tint(Theme.i1)
            }
            if draft.sources.isEmpty {
                Text("Pick at least one source.").font(.footnote).foregroundStyle(Theme.danger)
            }
        } header: {
            Text("Sources")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text(RuleSource.note)
                (Text("Reads as ") + Text(RuleSource.sentence(draft.sources, tier: draft.tier, roleName: roleName)).bold())
            }
        }
    }

    private func binding(_ source: RuleSource) -> Binding<Bool> {
        Binding(get: { draft.sources.contains(source) }, set: { on in
            var chosen = Set(draft.sources)
            if on { chosen.insert(source) } else { chosen.remove(source) }
            draft.sources = RuleSource.allCases.filter { chosen.contains($0) }
        })
    }
}
