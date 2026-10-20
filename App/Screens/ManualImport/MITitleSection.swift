import SwiftUI
import FusionhaKit

/// How a title's rows draw (`ManualImportLayout`).
enum MIRowMode: Equatable {
    /// Phone cards that open in place.
    case cards
    /// The Duo split's list: a tap shows the file in the detail pane.
    case pick
    /// The desktop table; `narrow` under 1100 drops Audio and Group · service.
    case table(narrow: Bool)
}

/// One title (the web's phone `TitleSection`): a flat header that folds, with
/// a select-all box, the poster, the title and its match confidence (a medium
/// match is a tag that asks "Right match?"), the meta line and Edit all; then
/// its rows.
struct MITitleSection: View {
    let block: ManualImportBlock
    /// The rows the current filter shows.
    let rows: [ManualImportRow]
    @Binding var folded: Bool
    @Binding var openId: Int?
    /// How its rows draw: phone cards, the Duo split's list, or table rows.
    var rowMode: MIRowMode = .cards
    @Environment(ManualImportSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var asking = false
    @State private var editAll = false
    @State private var rematch = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if block.needsConfirm && asking { ask }
            if !folded {
                switch rowMode {
                case .cards:
                    ForEach(rows) { row in MIRowView(row: row, openId: $openId) }
                case .pick:
                    ForEach(rows) { row in MIRowView(row: row, openId: $openId, picksDetail: true) }
                case .table(let narrow):
                    VStack(alignment: .leading, spacing: 4) {
                        MITableHead(narrow: narrow)
                        ForEach(rows) { row in MITableRow(row: row, narrow: narrow, openId: $openId) }
                    }
                }
            }
        }
        .sheet(isPresented: $editAll) {
            MIBulkSheet(title: "Edit all · \(block.title)", rows: block.rows.filter { !$0.committed })
                .environment(session)
        }
        .sheet(isPresented: $rematch) { MIItemMatchSheet(rows: block.rows).environment(session) }
    }

    private var header: some View {
        HStack(spacing: 8) {
            checkbox
            if !block.unmatched { ActPoster(url: block.posterUrl, title: block.title, size: .sm) }
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(block.title).font(Theme.display(20))
                        .foregroundStyle(block.unmatched ? Theme.danger : Theme.txt).lineLimit(1)
                    confidence
                }
                Text(meta).font(.system(size: 12)).foregroundStyle(Theme.mut).lineLimit(1)
            }
            Spacer(minLength: 0)
            if !block.unmatched {
                Button(block.rows.count > 1 ? "Edit all \(block.rows.count) files" : "Edit", systemImage: "pencil") {
                    if block.rows.count > 1 { editAll = true } else { toggleOpen(block.rows[0].rowId) }
                }
                .labelStyle(.iconOnly)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.txt)
                .frame(width: 36, height: 36)
                .glassControl()
            }
            Button(folded ? "Show \(block.title)" : "Hide \(block.title)", systemImage: "chevron.down") { fold() }
                .labelStyle(.iconOnly)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.mut)
                .rotationEffect(.degrees(folded ? -90 : 0))
                .frame(width: 36, height: 44)
        }
        .padding(.top, 8)
        .contentShape(Rectangle())
        .onTapGesture { fold() }
    }

    private var meta: String {
        let selected = block.rows.filter { session.selected.contains($0.rowId) }.count
        let look = block.rows.filter { !$0.committed && $0.status != "ready" }.count
        return [block.meta,
                folded && selected > 0 ? "\(selected) selected" : nil,
                folded && look > 0 ? "\(look) need\(look == 1 ? "s" : "") a look" : nil]
            .compactMap { $0 }.joined(separator: " · ")
    }

    @ViewBuilder private var confidence: some View {
        if block.needsConfirm {
            Button { withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) { asking.toggle() } } label: {
                Label(block.confidence, systemImage: "questionmark.diamond")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.miss)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .actWash(Theme.miss, mono: .miss, radius: 6, base: Theme.panel)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(block.confidence) match, tap to confirm or re-match")
        } else if !block.unmatched {
            Text(block.confidence).font(.system(size: 11, weight: .semibold))
                .foregroundStyle(block.confidence == "high" ? Theme.done : Theme.mut)
        }
    }

    /// "Right match? ✓ Yes · Re-match", plus what else it might be.
    private var ask: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.diamond").foregroundStyle(Theme.miss)
                Text("Right match?").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                Spacer(minLength: 0)
                ActAsyncButton(label: "Yes", systemImage: "checkmark") {
                    await session.confirm(block.rows)
                    asking = false
                    return true
                }
                Button("Re-match") { asking = false; rematch = true }.buttonStyle(ActButtonStyle(kind: .ghost))
            }
            if let alt = block.alternativeLine {
                Text(alt).font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
        }
        .padding(10)
        .actWash(Theme.miss, mono: .miss, radius: Theme.radius, base: Theme.panel)
        .disabled(session.bulkBusy || session.working)
    }

    private var checkbox: some View {
        let state = ManualImportBatch.checkState(block.rows, selected: session.selected)
        let glyph = switch state {
        case .on: "checkmark.square.fill"
        case .mixed: "minus.square.fill"
        case .off, .none: "square"
        }
        return Button {
            session.selected = ManualImportBatch.toggleBlock(block.rows, selected: session.selected)
        } label: {
            Image(systemName: glyph).font(.system(size: 20))
                .foregroundStyle(state == .on || state == .mixed ? Theme.i1 : Theme.dim)
                .frame(width: 40, height: 44)
        }
        .buttonStyle(.plain)
        .disabled(state == .none)
        .accessibilityLabel("Select all in \(block.title)")
        .accessibilityValue(state == .on ? "Selected" : state == .mixed ? "Some selected" : "Not selected")
    }

    private func fold() {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { folded.toggle() }
    }

    private func toggleOpen(_ id: Int) {
        if folded { folded = false }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { openId = openId == id ? nil : id }
    }
}
