import SwiftUI
import FusionhaKit

/// The fixes behind Tasks › Needs attention (web `EnrichmentGroup` /
/// `EnrichmentFileRow` mutations), shared by a file row and a group's bulk bar.
@MainActor
enum EnrichmentActions {
    static func confirmTitle(_ fix: EnrichmentFix, count: Int) -> String {
        let what = count == 1 ? "this file" : "\(count) files"
        switch fix {
        case .replace: return "Replace \(what)? Each is deleted and searched for again."
        case .delete: return "Delete \(what)? The slot is marked missing."
        case .forget:
            return "Forget \(count == 1 ? "this record" : "\(count) records")? Only the database row goes, unless you also delete from disk."
        case .retry: return ""
        }
    }

    static func run(_ fix: EnrichmentFix, ids: [Int], deleteFromDisk: Bool,
                    client: APIClient?, toaster: ActToaster) async {
        guard let client, !ids.isEmpty else { return }
        do {
            switch fix {
            case .retry:
                let n = try await client.requeueEnrichment(fileIds: ids)
                toaster.show(n == 0 ? "Those files couldn’t be queued again." : "Queued \(n) for another analysis.",
                             tone: n == 0 ? .warning : .success)
            case .replace:
                if ids.count == 1 { try await client.replaceFile(fileId: ids[0]) } else { try await client.bulkReplaceFiles(fileIds: ids) }
                toaster.show("Replaced. Searching for new copies.", tone: .success)
            case .delete:
                var failed = 0
                for id in ids { do { try await client.deleteFile(id: id, blocklist: false) } catch { failed += 1 } }
                toaster.show(failed > 0 ? "Removed \(ids.count - failed); \(failed) couldn’t be removed." : "Removed.",
                             tone: failed > 0 ? .warning : .success)
            case .forget:
                let r = try await client.forgetUnlinked(fileIds: ids, deleteFromDisk: deleteFromDisk)
                let skipped = r.skipped?.count ?? 0
                toaster.show(skipped > 0 ? "Forgot \(r.removed); \(skipped) left alone." : "Forgot \(r.removed).",
                             tone: skipped > 0 ? .warning : .success)
            }
        } catch APIError.http(409, _) {
            toaster.show("Mount not ready or the link recovered, so nothing was deleted.", tone: .warning)
        } catch {
            toaster.show(ErrorCopy.message(for: error, fallback: "That didn’t work. Try again."), tone: .error)
        }
    }
}

/// The destructive-fix confirmation for a set of files; `forget` offers the
/// disk delete as its second button.
struct EnrichmentConfirm: ViewModifier {
    @Binding var pending: (fix: EnrichmentFix, ids: [Int])?
    let run: (EnrichmentFix, [Int], Bool) -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            pending.map { EnrichmentActions.confirmTitle($0.fix, count: $0.ids.count) } ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible
        ) {
            if let c = pending {
                if c.fix == .forget {
                    Button("Forget record\(c.ids.count == 1 ? "" : "s")", role: .destructive) { run(.forget, c.ids, false) }
                    Button("Forget and delete from disk", role: .destructive) { run(.forget, c.ids, true) }
                } else {
                    Button(c.fix.label, role: .destructive) { run(c.fix, c.ids, false) }
                }
            }
        }
    }
}
