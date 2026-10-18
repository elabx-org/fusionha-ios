import SwiftUI
import FusionhaKit

/// The held download's reason strip (the web's `HeldStrip`): why it was held,
/// and for a pack, Keep all current / Import all over the held downgrades.
struct MIHeldStripView: View {
    let strip: ManualImportHeldStrip
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Theme.miss)
                (Text("Held").bold() + Text(strip.line1.map { " · " + $0 }.joined()))
                    .font(.subheadline).foregroundStyle(Theme.txt)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach([strip.line2, ManualImportRules.titleSummary(session.rows)].compactMap { $0 }, id: \.self) { line in
                Text(line).font(.footnote).foregroundStyle(Theme.mut).padding(.leading, 26)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if strip.bulkEligible > 0 {
                HStack(spacing: 8) {
                    ActAsyncButton(label: "Keep all current", systemImage: "internaldrive") { await bulk("keep_current") }
                    ActAsyncButton(label: "Import all", systemImage: "arrow.down") { await bulk("import") }
                }
                .disabled(session.bulkBusy || session.working)
                .padding(.leading, 26)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.miss.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.miss.opacity(0.25)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Held download")
    }

    /// Worked when no row the bulk touched came back with an error.
    private func bulk(_ choice: String) async -> Bool {
        await session.bulkHeld(choice)
        return session.rows.allSatisfy { session.rowErrors[$0.rowId] == nil }
    }
}

/// The import bar (the web's `StickyBar` with the rescue plan, 0.4.202): the
/// import mode, and the primary the plan names: N files need a decision, Force
/// import N, Finish download (a retry), or Done. Each download finishes on its
/// own as soon as its rows are decided, so there is no blocklist box here.
struct MIFooter: View {
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        @Bindable var session = session
        let plan = session.plan
        VStack(alignment: .leading, spacing: 8) {
            if let notice = session.notice {
                HStack(alignment: .top) {
                    Text(notice.text).font(.footnote).foregroundStyle(notice.error ? Theme.danger : Theme.miss)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("Dismiss", systemImage: "xmark") { session.notice = nil }
                        .labelStyle(.iconOnly).foregroundStyle(Theme.mut)
                }
            }
            if pendingTicked > 0 {
                Text("\(pendingTicked) file\(pendingTicked == 1 ? " is" : "s are") still being checked; the name-vs-file check hasn't run for \(pendingTicked == 1 ? "it" : "them") yet.")
                    .font(.footnote).foregroundStyle(Theme.mut)
            }
            HStack(spacing: 10) {
                MISelectionMenu()
                if plan.imports > 0 {
                    Menu {
                        Picker("Import mode", selection: $session.importMode) {
                            ForEach(ManualImportMode.allCases) { mode in
                                Text("\(mode.label) · \(mode.hint)").tag(mode)
                            }
                        }
                    } label: { GlassMenuLabel(title: session.importMode.label) }
                    .accessibilityLabel("Import mode, \(session.importMode.label)")
                }
                Spacer(minLength: 0)
                ActAsyncButton(label: plan.label,
                               systemImage: plan.kind == .keep ? "internaldrive" : plan.kind == .done ? nil : "square.and.arrow.down",
                               kind: .primary, workingLabel: plan.kind == .keep ? "Working…" : "Importing…",
                               externalWorking: session.working) {
                    await session.runPrimary()
                    return session.notice?.error != true
                }
                .disabled(plan.disabled || session.bulkBusy)
                .opacity(plan.disabled ? 0.5 : 1)
            }
            if let hint = plan.hint {
                Text(hint).font(.footnote).foregroundStyle(Theme.mut)
            } else {
                Text("Imports in place, no re-download.").font(.footnote).foregroundStyle(Theme.dim)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }

    private var pendingTicked: Int {
        session.rows.filter { session.selected.contains($0.rowId) && $0.probe?.isPending == true }.count
    }
}

/// "N selected" (web `SelectionActionsSheet`): confirm the selected medium
/// matches at once, select all, all ready, or none.
struct MISelectionMenu: View {
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        let open = session.rows.filter { !$0.committed }
        let picked = open.filter { session.selected.contains($0.rowId) }
        let toConfirm = picked.filter(ManualImportRules.confirmEligible)
        let ready = open.filter(ManualImportRules.isImportable)
        Menu {
            if !toConfirm.isEmpty {
                Button("Confirm \(toConfirm.count) medium match\(toConfirm.count == 1 ? "" : "es")", systemImage: "checkmark.seal") {
                    Task { for r in toConfirm { await session.patch(r, ["item_id": .optional(r.match.itemId)]) } }
                }
            }
            Button("Select all · \(open.count)") { session.selected = Set(open.map(\.rowId)) }
            Button("Select all ready · \(ready.count)") { session.selected = Set(ready.map(\.rowId)) }.disabled(ready.isEmpty)
            Button("Clear selection") { session.selected = [] }.disabled(picked.isEmpty)
        } label: {
            GlassMenuLabel(title: "\(picked.count) selected")
        }
        .disabled(session.working || session.bulkBusy)
    }
}
