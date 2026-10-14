import SwiftUI
import FusionhaKit

/// The opened row (the web's `RowBody`), each fact once: the decision, Import
/// as, Name vs file, then the file itself.
struct MIRowBody: View {
    let row: ManualImportRow
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MIRowDecision(row: row)
            section("Import as") { MIImportAsFields(row: row) }
            section("Name vs file") { nameVsFile }
            section("File") { fileBlock }
        }
        .padding(.leading, 48)
        .disabled(session.working)
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(Theme.dim)
            content()
        }
    }

    private var nameVsFile: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
            GridRow {
                Text("")
                Label("Name says", systemImage: "tag").foregroundStyle(Theme.dim)
                Label("File says", systemImage: "waveform.path.ecg").foregroundStyle(Theme.dim)
            }
            .font(.system(size: 11, weight: .semibold))
            ForEach(ManualImportCompare.nameFileRows(row), id: \.label) { r in
                GridRow {
                    Text(r.label).foregroundStyle(Theme.mut)
                    Text(r.name ?? "—")
                        .strikethrough(r.bad, color: Theme.miss)
                        .foregroundStyle(r.bad ? Theme.miss : r.name == nil ? Theme.dim : Theme.txt)
                    Text(r.file).foregroundStyle(Theme.txt)
                }
                .font(.system(size: 12.5))
            }
        }
    }

    private var fileBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(row.filename)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.txt)
                .textSelection(.enabled)
            if row.probe?.state == "failed" || row.probe?.state == "unsupported" {
                Text(ManualImportRules.probeErrorText(row.probe?.error))
                    .font(.footnote).foregroundStyle(Theme.danger)
            }
            if let note = row.retargetNote { Text(note).font(.footnote).foregroundStyle(Theme.mut) }
            Button("Copy path", systemImage: "doc.on.doc") { UIPasteboard.general.string = row.sourcePath }
                .buttonStyle(ActButtonStyle(kind: .ghost))
        }
    }
}

/// The one decision of an opened row (the web's `RowDecision`): a name ≠ file
/// or title ≠ episode resolve, then "Which file stays?" (held, not an upgrade
/// or already answered) or the upgrade compare, then the match check.
struct MIRowDecision: View {
    let row: ManualImportRow
    @Environment(ManualImportSession.self) private var session

    private var current: ManualImportExistingFile? { row.existingFile }
    private var notUpgrade: Bool { current?.verdict.map { $0.upgrade != true } ?? (row.held != nil) }
    private var picker: Bool {
        !row.committed && current != nil && (notUpgrade || row.held != nil || row.replaceChoice != nil)
    }
    private var mislabel: Bool { row.measured?.mislabeled == true && row.mismatchChoice == nil && row.held == nil }
    private var titleCheck: ManualImportAlternative? {
        guard let alt = row.match.alternative, alt.reason == "episode_title", row.titleCheckDismissed != true else { return nil }
        return alt
    }
    private var confirmable: Bool {
        !row.committed && row.status == "needs_attention" && row.match.itemId != nil
            && row.match.confidence != "high" && row.itemOverridden != true && !picker && !mislabel && titleCheck == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if current == nil, row.match.itemId != nil, !row.committed {
                Label("New · nothing on disk for this slot", systemImage: "plus.circle")
                    .font(.footnote).foregroundStyle(Theme.mut)
            }
            MITitleNote(row: row)
            MIAssignNote(row: row)
            if let runtime = ManualImportRules.runtimeLine(row) {
                Label("Runtime · \(runtime)", systemImage: "clock").font(.footnote).foregroundStyle(Theme.mut)
            }
            if mislabel, let m = row.measured, let p = row.probe { mislabelPanel(m, p) }
            if let alt = titleCheck { titlePanel(alt) }
            if picker {
                MIWhichFileStays(row: row, pending: session.pendingRows.contains(row.rowId)) { choice in
                    Task { await session.patch(row, ["replace_choice": .string(choice)]) }
                }
            } else if current != nil {
                MICompareTable(row: row, title: "Compared with the current file")
            }
            if confirmable {
                resolvePanel("Is \(row.match.title ?? "this title") the right match?") {
                    action("Confirm match", primary: true) { ["item_id": .optional(row.match.itemId)] }
                }
            }
        }
    }

    private func mislabelPanel(_ m: ManualImportMeasured, _ p: ManualImportProbe) -> some View {
        resolvePanel("Name says \(m.claimedResolution.map(String.init) ?? "?")p, the file is \(p.width ?? 0)×\(p.height ?? 0).") {
            if let q = m.quality, let tier = m.tier {
                action("Use \(DetailText.quality(q)) · \(ManualImportRules.tierLabel(tier))", primary: true) { ["mismatch_choice": "measured"] }
            }
            action("Keep \(DetailText.quality(row.quality)) · \(ManualImportRules.tierLabel(row.target.tier))", primary: false) {
                ["mismatch_choice": "name"]
            }
        }
    }

    private func titlePanel(_ alt: ManualImportAlternative) -> some View {
        let other = alt.title + (alt.year.map { " (\($0))" } ?? "")
        let mine = (row.match.title ?? "this title") + (row.match.year.map { " (\($0))" } ?? "")
        return resolvePanel("The episode title in the name belongs to \(other), also in your library.") {
            action("Re-match to \(other)", primary: true) { ["item_id": .int(alt.itemId)] }
            action("Keep as \(mine)", primary: false) { ["dismiss_title_check": true] }
        }
    }

    private func resolvePanel<C: View>(_ text: String, @ViewBuilder actions: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
                .fixedSize(horizontal: false, vertical: true)
            ActFlow(spacing: 8, lineSpacing: 8) { actions() }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.miss.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
    }

    private func action(_ label: String, primary: Bool, _ fields: @escaping () -> [String: SettingsJSON]) -> some View {
        Button(label) { Task { await session.patch(row, fields()) } }
            .buttonStyle(ActButtonStyle(kind: primary ? .primary : .subtle))
            .disabled(session.pendingRows.contains(row.rowId))
    }
}
