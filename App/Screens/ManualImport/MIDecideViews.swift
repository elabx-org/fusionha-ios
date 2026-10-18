import SwiftUI
import FusionhaKit

// Decide one file at a time (fusionha 0.4.202): the collapsed row's finding
// chips and actions, the Keep current menu, the opened row's three-way choice,
// the Done receipt and a pack's progress. Ported from the web's
// `routes/manual-import/decide/*`.

/// The collapsed row's second line: finding chips, and for a live held row
/// its action plus Keep current ▾. A decided row whose download finished (or
/// that imported) shows its receipt; a kept row of an unfinished pack says how
/// far the pack is.
struct MIFindingLine: View {
    let row: ManualImportRow
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        if let receipt = session.receipt(for: row) {
            MIReceiptView(receipt: receipt)
        } else {
            let chips = ManualImportDecide.findings(row)
            let tally = session.tally(for: row)
            let decided = ManualImportDecide.isDecided(row)
            let live = tally != nil && !decided && tally?.finished != true && !row.committed
            let waiting = tally.flatMap { decided && !$0.finished && $0.total > 1 ? $0 : nil }
            if !chips.isEmpty || live || waiting != nil {
                VStack(alignment: .leading, spacing: 8) {
                    if !chips.isEmpty || waiting != nil {
                        ActFlow(spacing: 6, lineSpacing: 6) {
                            ForEach(chips) { MIFindingChip(finding: $0) }
                            if let waiting {
                                Text("\(row.committed ? "Imported" : "Kept current") · pack \(waiting.decided) of \(waiting.total) decided")
                                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut)
                            }
                        }
                    }
                    if live { MIRowActions(row: row) }
                }
            }
        }
    }
}

/// One amber finding chip: the short text shows, the full reason is its label.
struct MIFindingChip: View {
    let finding: ManualImportDecide.Finding

    var body: some View {
        let lib = finding.tone == .library
        HStack(spacing: 4) {
            if let icon = finding.icon {
                Image(systemName: icon == .swap ? "arrow.left.arrow.right" : icon == .redirect ? "arrow.turn.down.right" : "exclamationmark.triangle")
                    .font(.system(size: 11, weight: .bold))
            }
            Text(finding.text).lineLimit(1)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(lib ? Theme.mut : Theme.miss)
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background((lib ? Theme.txt.opacity(0.06) : Theme.miss.opacity(0.14)), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(finding.sentence)
    }
}

/// The recommended action (or Import this file) and Keep current ▾.
struct MIRowActions: View {
    let row: ManualImportRow
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        let busy = session.busyRows.contains(row.rowId) || session.working
        let keepRec = ManualImportDecide.keepRecommended(row)
        HStack(spacing: 8) {
            if let action = ManualImportDecide.rowAction(row) {
                let lead = (action.recommended && !keepRec) || row.existingFile == nil
                ActAsyncButton(label: action.label, systemImage: icon(action.kind), kind: lead ? .primary : .subtle) {
                    await session.importRow(row, action)
                    return session.rowErrors[row.rowId] == nil
                }
                .disabled(busy)
            }
            MIKeepMenu(row: row, recommended: keepRec, menuOnly: row.existingFile == nil)
                .disabled(busy)
        }
    }

    private func icon(_ kind: ManualImportDecide.RowAction.Kind) -> String {
        switch kind {
        case .assign: return "arrow.left.arrow.right"
        case .rematch: return "arrow.turn.down.right"
        case .importFile: return "square.and.arrow.down"
        }
    }
}

/// "Keep current ▾": the main half keeps with the preferred disposition; the
/// menu offers remove / remove + blocklist / leave. An empty slot has only the
/// menu ("More"), since Import leads there.
struct MIKeepMenu: View {
    let row: ManualImportRow
    let recommended: Bool
    var menuOnly = false
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        let choice = session.keepChoice(for: row)
        HStack(spacing: 2) {
            if !menuOnly {
                ActAsyncButton(label: choice.verb, systemImage: "internaldrive", kind: recommended ? .primary : .subtle) {
                    await session.keepRow(row, choice.preferred)
                    return session.rowErrors[row.rowId] == nil
                }
                .accessibilityHint(choice.preferredOption.label)
            }
            Menu {
                ForEach(choice.options) { option in
                    Button {
                        Task { await session.keepRow(row, option.value) }
                    } label: {
                        Text(option.label + (option.recommended ? " · Recommended" : ""))
                        Text(option.detail)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    if menuOnly { Text("More") }
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.txt)
                .padding(.horizontal, 12)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("\(choice.verb) options")
        }
    }
}

/// The opened held row's decision: the finding sentences, the files compared,
/// then the three-way Keep current choice beside the row's own action.
struct MIHeldDecision: View {
    let row: ManualImportRow
    @Environment(ManualImportSession.self) private var session
    @State private var picked: FinishDisposition?

    var body: some View {
        let choice = session.keepChoice(for: row)
        let sel = picked ?? choice.preferred
        let instead = ManualImportDecide.rowAction(row) ?? ManualImportDecide.importAction(row)
        let skip = choice.verb != "Keep current"
        VStack(alignment: .leading, spacing: 12) {
            ForEach(ManualImportDecide.sentences(row), id: \.self) { line in
                Label(line, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(Theme.miss)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if row.existingFile != nil {
                MICompareTable(row: row, title: "Which file stays?")
            } else {
                Label("New · nothing on disk for this slot", systemImage: "plus.circle").font(.footnote).foregroundStyle(Theme.mut)
            }
            Text(skip ? "Skip this file: nothing is imported for it"
                 : "Keep \(choice.group.map { "your \($0) copy" } ?? "your current copy") and skip this file")
                .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
            VStack(spacing: 6) {
                ForEach(choice.options) { o in optionRow(o, on: o.value == sel) }
            }
            if choice.linked {
                Label("Your library links into this download, so it is only cleared from the queue, never deleted.",
                      systemImage: "info.circle").font(.footnote).foregroundStyle(Theme.mut)
            }
            ActFlow(spacing: 8, lineSpacing: 8) {
                ActAsyncButton(label: choice.options.first { $0.value == sel }?.label ?? choice.verb, systemImage: "internaldrive",
                               kind: .primary) {
                    await session.keepRow(row, sel)
                    return session.rowErrors[row.rowId] == nil
                }
                if let instead {
                    ActAsyncButton(label: "\(instead.label) instead", kind: .subtle) {
                        await session.importRow(row, instead)
                        return session.rowErrors[row.rowId] == nil
                    }
                }
            }
            .disabled(session.busyRows.contains(row.rowId) || session.working)
        }
    }

    private func optionRow(_ o: ManualImportDecide.KeepOption, on: Bool) -> some View {
        Button { picked = o.value } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: on ? "largecircle.fill.circle" : "circle").foregroundStyle(on ? Theme.i1 : Theme.dim)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(o.label).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                        if o.recommended {
                            Text("Recommended").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.done)
                        }
                    }
                    Text(o.detail).font(.system(size: 12)).foregroundStyle(Theme.mut).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                .strokeBorder(on ? Theme.i1 : Theme.line, lineWidth: on ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// A decided row's Done receipt: exactly what happened, and no Undo.
struct MIReceiptView: View {
    let receipt: ManualImportDecide.Receipt

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.done)
            (Text(receipt.title).bold().foregroundColor(Theme.txt)
             + Text(receipt.detail.map { " · \($0)" } ?? "").foregroundColor(Theme.mut))
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A held pack's progress: "Pack: 3 of 13 decided · finishes when all are decided".
struct MIPackProgress: View {
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        let scan = session.scan
        let packs = session.tallies.values.filter { $0.total > 1 && !$0.finished }.sorted { $0.id < $1.id }
        ForEach(packs, id: \.id) { t in
            let rows = session.rows.filter { ManualImportDecide.downloadId($0, scan) == t.id }
            VStack(alignment: .leading, spacing: 6) {
                Text(ManualImportDecide.packName(rows)).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
                Text("Pack: \(t.decided) of \(t.total) decided · finishes when all are decided")
                    .font(.footnote).foregroundStyle(Theme.mut)
                ProgressView(value: Double(t.decided), total: Double(max(t.total, 1))).tint(Theme.miss)
                    .accessibilityLabel("Pack decided")
            }
            .padding(12)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        }
    }
}
