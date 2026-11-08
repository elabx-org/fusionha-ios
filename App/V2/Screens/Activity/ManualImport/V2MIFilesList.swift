import SwiftUI
import FusionhaKit

/// The Files segment (mock bulk `fileRows`): every file on one card, rows
/// split by hairlines (`V2MIFileRow`). A tap on a row opens the file. A drag
/// down the tick column ticks every row it passes (or unticks them, when it
/// began on a ticked row). On an iPad keyboard j/k move a cursor ring
/// through the rows, Space ticks the row and Return opens it.
struct V2MIFilesList: View {
    let open: (Int) -> Void
    @Environment(ManualImportSession.self) private var session
    @Environment(V2MIDraftStore.self) private var store
    @Environment(\.motionEnabled) private var motion
    /// Each row's vertical span in the list's space, for the sweep.
    @State private var spans: [Int: ClosedRange<Double>] = [:]
    @State private var sweep: Sweep?
    @State private var sweepTicks = 0
    @FocusState private var focus: Focus?
    /// The ring shows once a key moved it (a tap may focus a row too).
    @State private var keyed = false

    static let space = "v2-mi-files"

    private struct Sweep {
        let anchor: Int
        let on: Bool
        let base: Set<Int>
    }

    private enum Focus: Hashable {
        case list
        case row(Int)
    }

    var body: some View {
        let rows = session.rows.filter { store.shows($0, session) }
        if rows.isEmpty {
            Text("No files here.").font(.footnote).foregroundStyle(Theme.mut).padding(.top, 8)
        } else {
            list(rows)
        }
    }

    private func list(_ rows: [ManualImportRow]) -> some View {
        let ids = rows.map(\.rowId)
        let locked = Set(rows.filter(\.committed).map(\.rowId))
        return ModuleRows {
            ForEach(rows) { row in
                V2MIFileRow(row: row, cursor: keyed && focus == .row(row.rowId), open: open,
                            sweep: { anchor, y in swept(anchor: anchor, y: y, ids: ids, locked: locked) },
                            sweepEnded: { sweep = nil })
                    .onGeometryChange(for: ClosedRange<Double>.self) { proxy in
                        let frame = proxy.frame(in: .named(Self.space))
                        return Double(frame.minY)...Double(max(frame.minY, frame.maxY))
                    } action: { spans[row.rowId] = $0 }
                    .focusable()
                    .focused($focus, equals: .row(row.rowId))
                    .focusEffectDisabled()
            }
        }
        .padding(.horizontal, 14)
        .background { ModuleSurface(radius: 18) }
        .coordinateSpace(.named(Self.space))
        .focusable()
        .focused($focus, equals: .list)
        .focusEffectDisabled()
        .onKeyPress(characters: CharacterSet(charactersIn: "jkJK"), phases: [.down, .repeat]) { press in
            step(press.characters.lowercased() == "j" ? 1 : -1, ids: ids)
        }
        .onKeyPress(.space) { tickCursor(rows) }
        .onKeyPress(.return) { openCursor(ids) }
        .onAppear { if focus == nil { focus = .list } }
        .sensoryFeedback(.selection, trigger: sweepTicks)
    }

    // MARK: Sweep

    private func swept(anchor: Int, y: Double, ids: [Int], locked: Set<Int>) {
        let current = sweep ?? Sweep(anchor: anchor, on: !session.selected.contains(anchor), base: session.selected)
        if sweep == nil { sweep = current }
        guard let target = MIRowSweep.row(at: y, ids: ids, spans: spans) else { return }
        let run = MIRowSweep.run(from: current.anchor, to: target, ids: ids)
        let next = MIRowSweep.selection(base: current.base, run: run, on: current.on, locked: locked)
        guard next != session.selected else { return }
        session.selected = next
        sweepTicks += 1
    }

    // MARK: Keys

    private var cursor: Int? {
        if case .row(let id)? = focus { return id }
        return nil
    }

    private func step(_ by: Int, ids: [Int]) -> KeyPress.Result {
        guard let next = MIRowSweep.step(cursor, by: by, ids: ids) else { return .ignored }
        keyed = true
        withAnimation(motion ? .snappy(duration: 0.18) : nil) { focus = .row(next) }
        return .handled
    }

    private func tickCursor(_ rows: [ManualImportRow]) -> KeyPress.Result {
        guard let id = cursor, let row = rows.first(where: { $0.rowId == id }) else { return .ignored }
        session.toggle(row)
        return .handled
    }

    private func openCursor(_ ids: [Int]) -> KeyPress.Result {
        guard let id = cursor, ids.contains(id) else { return .ignored }
        open(id)
        return .handled
    }
}
