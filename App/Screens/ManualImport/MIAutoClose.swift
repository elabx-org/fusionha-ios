import SwiftUI
import FusionhaKit

/// Opened for one held download, Manual Import closes itself once that
/// download finishes (owner-approved item 5): after a beat (at once with
/// Reduce Motion), never while anything is in flight, and the shell toast
/// names the title and the outcome. Several downloads and folder scans keep Done.
extension ManualImportSession {
    /// The one held download this sheet was opened for.
    var soleDownload: Int? { rescueIds.count == 1 ? rescueIds.first : nil }

    /// This sheet finished its one download cleanly and nothing is in flight.
    var autoClosesNow: Bool {
        guard let id = soleDownload, finishedHere.contains(id), closing == nil else { return false }
        return !working && applying == nil && busyRows.isEmpty && inflight.isEmpty && pendingRows.isEmpty
            && notice?.error != true
    }

    /// "Interstellar · kept your FraMeSToR copy · download removed".
    var autoCloseText: String {
        guard let id = soleDownload else { return closingText }
        let mine = rows.filter { ManualImportDecide.downloadId($0, scan) == id }
        return ManualImportDecide.closingLine(mine.isEmpty ? rows : mine, finish: finishResults[id],
                                              currentGroup: scan?.heldDetail?.currentGroup)
    }
}

struct MIAutoClose: ViewModifier {
    let session: ManualImportSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.task(id: session.autoClosesNow) {
            guard session.autoClosesNow else { return }
            // A beat to see the receipt land; a new commit cancels this task.
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(800)) }
            guard !Task.isCancelled, session.autoClosesNow else { return }
            session.closing = (session.autoCloseText, false)
        }
    }
}
