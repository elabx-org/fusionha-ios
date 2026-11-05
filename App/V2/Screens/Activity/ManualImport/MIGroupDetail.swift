import SwiftUI
import FusionhaKit

/// One card opened (mock `drill`): its title with the card's choice as a
/// menu ("Keep yours ▾", or "Mixed ▾" once files were set one by one), the
/// sentence, then each file as yours against this download with its own
/// choices. A file's own choice outranks the card's; the menu says when a
/// choice would replace them.
struct MIGroupDetail: View {
    let problem: MIProblem
    @Environment(ManualImportSession.self) private var session
    @Environment(V2MIDraftStore.self) private var store
    @Environment(\.pagePalette) private var page

    var body: some View {
        if let g = store.group(problem, session) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 10) {
                    Text(MIProblemCopy.title(g.problem, count: g.rows.count))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(page?.ink ?? Theme.txt)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 8)
                    menu(g)
                }
                if let why = MIProblemCopy.why(g) {
                    Text(why.plain)
                        .font(.system(size: 12.5))
                        .foregroundStyle(page?.inkMuted ?? Theme.mut)
                        .padding(.top, 5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: 10) {
                    ForEach(g.rows) { MIFileCompareCard(row: $0, group: g) }
                }
                .padding(.top, 12)
            }
        } else {
            Text("These files are decided.").font(.footnote).foregroundStyle(Theme.mut)
        }
    }

    @ViewBuilder private func menu(_ g: MIGroup) -> some View {
        let rows = session.rows
        let options = MIProblemGrouping.groupOptions(g, rows: rows)
        let state = store.draft.state(g, rows: rows)
        if !options.isEmpty {
            Menu {
                switch state {
                case .uniform(let chosen):
                    ForEach(options) { c in
                        Button { store.draft.setGroup(g.problem, c) } label: {
                            if chosen == c { Label(label(c, g), systemImage: "checkmark") } else { Text(label(c, g)) }
                        }
                    }
                case .mixed:
                    Section("Files not set on their own") {
                        ForEach(options) { c in
                            Button(label(c, g)) { store.draft.setGroup(g.problem, c) }
                        }
                    }
                    Section("Every file, replacing their own choices") {
                        ForEach(options) { c in
                            Button("\(label(c, g)) for all \(g.rows.count)") { store.draft.setEveryFile(g, c) }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(menuTitle(state, g))
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
                }
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 12)
                .frame(height: 32)
                .glassEffect(.regular.interactive(), in: .capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choice for all \(g.rows.count)")
            .accessibilityValue(menuTitle(state, g))
        }
    }

    private func label(_ c: MIChoice, _ g: MIGroup) -> String {
        MIProblemCopy.label(c, g.problem, count: g.rows.count, row: g.rows.first)
    }

    private func menuTitle(_ state: MIDraft.GroupState, _ g: MIGroup) -> String {
        switch state {
        case .mixed: return "Mixed"
        case .uniform(let c?): return label(c, g)
        case .uniform(nil): return "Decide"
        }
    }
}
