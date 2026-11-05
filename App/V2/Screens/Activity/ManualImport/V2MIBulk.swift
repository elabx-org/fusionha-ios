import SwiftUI
import FusionhaKit

/// The ticked files' choices, staged onto the page's choices (they apply
/// with everything else from the footer). The bulk rules stay v1's
/// approved ones: bulk Import never replaces a better copy ("Import 1 of
/// 4"), Keep yours only where you have a copy, Skip only where you don't.
enum V2MIBulkOption: Hashable, CaseIterable {
    case picks, importFile, keep, skip
}

extension V2MIDraftStore {
    func stage(option: V2MIBulkOption, _ s: ManualImportSession) {
        switch option {
        case .picks: usePicks(s)
        case .importFile: stage(.importFile, s)
        case .keep: stage(.keepCurrent, s)
        case .skip: stage(.skip, s)
        }
    }

    /// What each option is called for the ticked files, and whether it can run.
    func bulkLabel(_ option: V2MIBulkOption, _ s: ManualImportSession) -> (title: String, detail: String, enabled: Bool) {
        let b = s.bulk
        switch option {
        case .picks:
            let n = tickedPicks(s)
            return ("Use Fusionha’s picks", n == b.n ? "Each ticked file takes the server’s pick" : "\(n) of \(b.n) have a pick", n > 0)
        case .importFile:
            return (b.imp.isEmpty ? "Import" : "Import \(b.of(b.imp.count))", b.impOutcome ?? b.reasons.imp ?? "", !b.imp.isEmpty)
        case .keep:
            return (b.keep.isEmpty ? "Keep yours" : "Keep yours for \(b.of(b.keep.count))",
                    b.keep.isEmpty ? (b.reasons.keep ?? "") : "Nothing imports for these; your copies stay", !b.keep.isEmpty)
        case .skip:
            return (b.skipLabel, b.skipOutcome ?? b.reasons.skip ?? "Only for files with nothing in their slot", !b.skip.isEmpty)
        }
    }
}

/// Phone and folded Duo (mock `bulkBar`): a system bottom bar with words,
/// "N selected", the Decide menu (Fusionha's picks first, only where the
/// server gives them) and the prominent "Import 1 of 4".
struct V2MIBulkBar: ViewModifier {
    let active: Bool
    @Environment(ManualImportSession.self) private var session
    @Environment(V2MIDraftStore.self) private var store
    @State private var editing = false

    func body(content: Content) -> some View {
        let b = session.bulk
        content
            .toolbar {
                if active {
                    ToolbarItem(placement: .bottomBar) {
                        Text("\(b.n) selected").font(.subheadline.weight(.semibold)).monospacedDigit()
                    }
                    ToolbarSpacer(.flexible, placement: .bottomBar)
                    ToolbarItem(placement: .bottomBar) { decide }
                    ToolbarItem(placement: .bottomBar) {
                        Button(store.bulkLabel(.importFile, session).title) { store.stage(option: .importFile, session) }
                            .fontWeight(.semibold)
                            .buttonStyle(.glassProminent)
                            .tint(Theme.primary)
                            .disabled(b.imp.isEmpty)
                            .accessibilityHint(b.importSubtitle)
                    }
                }
            }
            .publishesSelectBar("manual-import.bulk", active: active)
            .duoPageSheet(isPresented: $editing) {
                MIBulkSheet(title: "Edit \(b.open.count) selected", rows: b.open).environment(session)
            }
    }

    private var decide: some View {
        @Bindable var session = session
        return Menu {
            Section("\(session.bulk.n) selected") {
                ForEach([V2MIBulkOption.picks, .importFile, .keep, .skip], id: \.self) { option in
                    let l = store.bulkLabel(option, session)
                    if option != .picks || l.enabled {
                        Button { store.stage(option: option, session) } label: {
                            Label(l.title, systemImage: Self.icon(option))
                            Text(l.detail)
                        }
                        .disabled(!l.enabled)
                    }
                }
            }
            Section {
                Picker(selection: $session.importMode) {
                    ForEach(ManualImportMode.allCases) { Text("\($0.label) · \($0.hint)").tag($0) }
                } label: {
                    Label("Import mode", systemImage: "arrow.left.arrow.right")
                    Text(session.importMode.label)
                }
                .pickerStyle(.menu)
                let confirm = session.tickedToConfirm
                if !confirm.isEmpty {
                    Button("Confirm \(confirm.count) match\(confirm.count == 1 ? "" : "es")", systemImage: "checkmark") {
                        Task { await session.confirm(confirm) }
                    }
                }
                Button("Edit \(session.bulk.open.count) selected…", systemImage: "pencil") { editing = true }
                    .disabled(session.bulk.open.isEmpty)
            }
            Section {
                MISelectUndecidedButton(showsCount: true)
                Button("Clear selection", systemImage: "xmark.circle") { session.selected = [] }
            }
        } label: {
            Text("Decide")
        }
        .accessibilityValue("\(session.bulk.n) selected")
    }

    static func icon(_ o: V2MIBulkOption) -> String {
        switch o {
        case .picks: return "checkmark"
        case .importFile: return "square.and.arrow.down"
        case .keep: return "arrow.uturn.backward"
        case .skip: return "xmark"
        }
    }
}

extension View {
    func v2MIBulkBar(active: Bool) -> some View { modifier(V2MIBulkBar(active: active)) }
}
