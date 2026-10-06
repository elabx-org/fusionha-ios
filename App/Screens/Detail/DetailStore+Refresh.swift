import Foundation
import FusionhaKit

// Item and season refresh, polled to completion like the web's useBackgroundRefresh.
extension DetailStore {
    // MARK: Refresh

    func refresh(metadataOnly: Bool) async {
        guard let client, let title = detail?.title else { return }
        refreshing = true
        defer { refreshing = false }
        do {
            let dispatch = try await client.refreshItem(id: itemId, metadataOnly: metadataOnly)
            let run = await waitForRun(dispatch.runId)
            await reload()
            if run?.status == "failed" {
                show("Couldn't refresh \(title)", variant: .error)
            } else {
                showRescan(run?.rescanSummary, title: title)
            }
        } catch {
            show("Couldn't refresh \(title)", variant: .error)
        }
    }

    func refreshSeason(_ number: Int) async {
        guard let client else { return }
        let name = number == 0 ? "Specials" : "Season \(number)"
        do {
            let dispatch = try await client.refreshSeason(itemId: itemId, season: number)
            show("Refreshing \(name)…")
            let run = await waitForRun(dispatch.runId)
            await reload()
            showRescan(run?.rescanSummary, title: name)
        } catch {
            show("Couldn't refresh \(name)", variant: .error)
        }
    }

    func waitForRun(_ id: Int) async -> CommandRun? {
        guard let client else { return nil }
        for _ in 0..<200 {
            try? await Task.sleep(for: .seconds(1.5))
            if let run = try? await client.commandRun(id: id), !run.isRunning { return run }
        }
        return nil
    }

    /// `rescanSummaryToast`.
    private func showRescan(_ summary: RescanSummary?, title: String) {
        let heading = "Refreshed \(title)"
        guard let summary else { show("Metadata updated.", title: heading, variant: .success); return }
        var clauses: [String] = []
        var variant: DetailToast.Variant = .success
        let standdown = summary.standdown ?? []
        if !standdown.isEmpty {
            let labels = standdown.compactMap { id in detail?.editions.first { $0.id == id }?.tier.chipLabel }
            let folder = standdown.count > 1 ? "library folders look" : "library folder looks"
            clauses.append("\(labels.isEmpty ? "A" : labels.joined(separator: ", ")) \(folder) unreachable — skipped, nothing touched.")
            variant = .warning
        }
        let unresolved = (summary.flagged ?? 0) + (summary.dangling ?? 0)
        if unresolved > 0 {
            clauses.append("\(unresolved) \(unresolved == 1 ? "file" : "files") couldn't be resolved on the last scan — none removed yet (confirming over the safety window).")
            variant = .warning
        }
        var changes: [String] = []
        if let n = summary.attached, n > 0 { changes.append("\(n) imported") }
        if let n = summary.healed, n > 0 { changes.append("\(n) recovered") }
        if let n = summary.removed, n > 0 { changes.append("\(n) removed") }
        if let n = summary.probed, n > 0 { changes.append("\(n) re-analysed") }
        if !changes.isEmpty { clauses.append(changes.joined(separator: " · ") + ".") }
        if clauses.isEmpty { show("No changes.", title: heading, variant: .info); return }
        show(clauses.joined(separator: " "), title: heading, variant: variant)
    }
}
