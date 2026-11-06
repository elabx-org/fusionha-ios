import SwiftUI
import FusionhaKit

// v2's fold continuity (`docs/v2.md`, "Fold continuity"; `FoldKeep`, nil in
// v1, where none of this runs). On the open Duo Add is both pages, folded a
// sheet: a fold swaps the presentation, which builds this view again. What
// was typed and picked rides across in the window's `FoldKeep`, and the new
// host takes it back while the old one is still leaving or has just left.

/// What Add carries across a fold.
@MainActor
final class AddFoldCarry {
    var query = ""
    var kind: SearchKind = .all
    var source: MetadataSource = .tmdb
    var gridView = true
    var flow: AddFlow?
    var requestPick: MediaSearchResult?
    var sessionProvider = "auto"
    var autoPicked = false
    var path = NavigationPath()
    /// A host is on screen with it, or left at `leftAt`.
    var alive = false
    var leftAt: Date = .distantPast

    /// A host that left this recently was swapped by a fold, not closed.
    static let swapWindow: TimeInterval = 3
    var fresh: Bool { alive || Date().timeIntervalSince(leftAt) < Self.swapWindow }
}

/// The values that change what a host would carry.
struct AddFoldState: Equatable {
    let query: String
    let kind: SearchKind
    let source: MetadataSource
    let gridView: Bool
    let flow: ObjectIdentifier?
    let requestPick: Int?
    let sessionProvider: String
    let autoPicked: Bool
    let path: NavigationPath
}

extension AddTitleSheet {
    private var foldKey: String { "add-" + (initialPick?.key ?? "find") }

    var foldState: AddFoldState {
        AddFoldState(query: query, kind: kind, source: source, gridView: gridView, flow: flow.map { ObjectIdentifier($0) },
                     requestPick: requestPick?.tmdbId, sessionProvider: sessionProvider, autoPicked: autoPicked, path: path)
    }

    /// On appear: takes back what the host before it carried (true), else
    /// starts carrying for the next one.
    func restoreFromFold() -> Bool {
        guard let foldKeep else { return false }
        let carry = foldKeep.object(foldKey) { AddFoldCarry() }
        defer { carry.alive = true }
        guard carry.fresh, carry.flow != nil || carry.requestPick != nil || !carry.query.isEmpty else {
            // A new Add: nothing older may ride into the next fold.
            carryForFold()
            return false
        }
        query = carry.query
        kind = carry.kind
        source = carry.source
        gridView = carry.gridView
        flow = carry.flow
        requestPick = carry.requestPick
        sessionProvider = carry.sessionProvider
        autoPicked = carry.autoPicked
        path = carry.path
        return true
    }

    func carryForFold() {
        guard let carry = foldKeep?.existing(foldKey, as: AddFoldCarry.self) else { return }
        carry.query = query
        carry.kind = kind
        carry.source = source
        carry.gridView = gridView
        carry.flow = flow
        carry.requestPick = requestPick
        carry.sessionProvider = sessionProvider
        carry.autoPicked = autoPicked
        carry.path = path
    }

    func leftForFold() {
        guard let carry = foldKeep?.existing(foldKey, as: AddFoldCarry.self) else { return }
        carryForFold()
        carry.alive = false
        carry.leftAt = Date()
    }
}

extension View {
    /// Add's fold carry (`AddTitleSheet+FoldKeep`); nothing in v1.
    func addFoldCarry(_ sheet: AddTitleSheet) -> some View {
        onChange(of: sheet.foldState) { sheet.carryForFold() }
            .onDisappear { sheet.leftForFold() }
    }
}
