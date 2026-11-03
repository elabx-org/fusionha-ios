import SwiftUI
import FusionhaKit

/// The bulk bar (owner-approved "bar in every scenario"): while files are
/// ticked it replaces the import footer, in held, not-held and folder scans
/// alike. A system bottom bar, so iOS can move it into the closed iPhone
/// Duo's vertical bar (the Library's select bar does the same). On the phone
/// and the folded Duo (compact width) it speaks in words (owner-approved item
/// 4): a "Decide" text menu that also holds Select all undecided, and the
/// prominent "Import N" / "Import 1 of 4"; the outcome card is one line plus
/// More. Wider, Select all undecided (⌘A) keeps its own item. The outcome
/// card above it is solid content, never glass.
struct MIBulkBar: ViewModifier {
    let active: Bool
    @Environment(ManualImportSession.self) private var session
    @State private var editing = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        let s = session.bulk
        let busy = session.applying != nil || session.working || session.bulkBusy
        let compact = sizeClass == .compact
        content
            .toolbar {
                if active {
                    ToolbarItem(placement: .bottomBar) { decideMenu(s, compact: compact, busy: busy) }
                    ToolbarSpacer(.flexible, placement: .bottomBar)
                    if !compact {
                        ToolbarItem(placement: .bottomBar) { MISelectUndecidedButton() }
                            .barPriority(false)
                    }
                    ToolbarItem(placement: .bottomBar) { importButton(s, compact: compact, busy: busy) }
                        .barPriority(true)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if active {
                    MIBulkOutcome(summary: s, oneLine: compact).padding(.horizontal, 10).padding(.bottom, 6)
                }
            }
            .publishesSelectBar("manual-import.bulk", active: active)
            .duoPageSheet(isPresented: $editing) {
                MIBulkSheet(title: "Edit \(s.open.count) selected", rows: s.open).environment(session)
            }
    }

    /// Decide: a text menu on the phone and the folded Duo, headed "N selected".
    private func decideMenu(_ s: ManualImportBulkSummary, compact: Bool, busy: Bool) -> some View {
        Menu {
            MIDecideMenuItems(editing: $editing, selectsUndecided: compact)
        } label: {
            if compact { Text("Decide") } else { Label("Decide", systemImage: "checklist") }
        }
        .disabled(busy)
        .accessibilityIdentifier("mi.bulk.decide")
        .accessibilityLabel("Decide")
        .accessibilityValue("\(s.n) selected")
    }

    /// The prominent Import N ("Import 1 of 4"): words on compact widths.
    @ViewBuilder private func importButton(_ s: ManualImportBulkSummary, compact: Bool, busy: Bool) -> some View {
        let title = MIBulkWords.importTitle(s, applying: session.applying)
        let importing = session.applying?.action == .importFile
        Group {
            if compact {
                Button { runImport() } label: { Text(title).fontWeight(.semibold) }
                    .accessibilityValue(importing ? "In progress" : "")
            } else {
                ToolbarActionButton(title: title, systemImage: "square.and.arrow.down", busy: importing) { runImport() }
            }
        }
        .buttonStyle(.glassProminent)
        .tint(Theme.i1)
        .disabled(s.imp.isEmpty || busy)
        .accessibilityHint(s.importSubtitle)
        .accessibilityIdentifier("mi.bulk.import")
    }

    private func runImport() {
        Task { await session.decide(.importFile) }
    }
}

/// Select all undecided: exactly the files still waiting on a decision. ⌘A
/// (not a bare A) runs it from a hardware keyboard.
struct MISelectUndecidedButton: View {
    var showsCount = false
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        let ids = ManualImportBulk.undecided(session.bulkContext).filter { !$0.committed }.map(\.rowId)
        let n = ids.count
        let all = n > 0 && session.selected.isSuperset(of: ids)
        Button(showsCount ? "Select all undecided (\(n))" : "Select all undecided", systemImage: "checkmark.rectangle.stack") {
            session.selectAllUndecided()
        }
        .keyboardShortcut("a", modifiers: .command)
        .disabled(n == 0 || all || session.applying != nil)
    }
}

/// The bar's and the panel's shared words.
enum MIBulkWords {
    static func importTitle(_ s: ManualImportBulkSummary, applying: ManualImportSession.Applying?) -> String {
        if let applying, applying.action == .importFile { return applying.label }
        return s.imp.isEmpty ? "Import" : "Import \(s.of(s.imp.count))"
    }

    static func keepTitle(_ s: ManualImportBulkSummary, applying: ManualImportSession.Applying?) -> String {
        if let applying, applying.action == .keepCurrent { return applying.label }
        return s.keep.isEmpty ? "Keep current" : "Keep current \(s.of(s.keep.count))"
    }
}

extension View {
    /// The bulk bar while files are ticked (`MIBulkBar`).
    func miBulkBar(active: Bool) -> some View {
        modifier(MIBulkBar(active: active))
    }
}
