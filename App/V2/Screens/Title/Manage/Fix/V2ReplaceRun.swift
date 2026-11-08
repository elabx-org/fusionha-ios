import SwiftUI
import FusionhaKit

/// "Replace without waiting" (owner-approved mock, 2026-11-08). Fix mode's
/// Replace hands its files here and closes at once. The files go to the
/// server together; the title page's episode rows show "Searching…"; a
/// glass toast says it started. If the server is slower than `patience`, a
/// toast says it's still searching (with Activity); the last toast says what
/// came back, and a slow answer is never called a failure.
@MainActor
enum V2ReplaceRun {
    static let patience: Duration = .seconds(25)

    static func start(_ items: [ManagedFileItem], blocklisting: Set<Int>, detail: ItemDetail,
                      client: APIClient, app: AppModel, store: DetailStore) {
        let jobs = ReplacePlan.jobs(items, blocklisting: blocklisting, detail: detail)
        guard !jobs.isEmpty else { return }
        var begun: [SearchTarget: Int] = [:]
        for target in jobs.flatMap(\.targets) {
            if let token = store.searchActivity.begin(target) { begun[target] = token }
        }
        let tokens = begun
        let searching = jobs.filter(\.searches).count
        if searching > 0 {
            app.toast(searching == 1 ? "Searching for a new copy" : "Searching for \(searching) new copies", variant: .info)
        }
        Task { @MainActor in
            let slowNote = Task { @MainActor in
                try? await Task.sleep(for: patience)
                guard !Task.isCancelled else { return }
                app.toast("Still searching on the server", variant: .info, action: activity(app))
            }
            let results = await run(jobs, client: client)
            slowNote.cancel()
            finish(jobs, results, tokens: tokens, store: store)
            let searched = zip(jobs, results).filter { $0.0.searches && $0.1 == .done }.count
            let summary = ReplacePlan.summary(results, searched: searched)
            if !summary.message.isEmpty {
                app.toast(summary.message, variant: summary.isError ? .error : .success,
                          action: summary.pointsToActivity ? activity(app) : nil)
            }
            await store.reload()
            app.refreshLibrarySoon()
            try? await Task.sleep(for: .seconds(DetailStore.searchOutcomeSeconds))
            for (target, token) in tokens { store.searchActivity.clear(target, token: token) }
        }
    }

    /// Every job at once; results in the jobs' order.
    private static func run(_ jobs: [ReplaceJob], client: APIClient) async -> [ReplacePlan.Result] {
        await withTaskGroup(of: (Int, ReplacePlan.Result).self) { group in
            for (i, job) in jobs.enumerated() {
                group.addTask {
                    do {
                        try await send(job, client: client)
                        return (i, .done)
                    } catch {
                        return (i, ReplacePlan.result(of: error, kind: job.kind))
                    }
                }
            }
            var out = Array(repeating: ReplacePlan.Result.failed, count: jobs.count)
            for await (i, result) in group { out[i] = result }
            return out
        }
    }

    nonisolated private static func send(_ job: ReplaceJob, client: APIClient) async throws {
        switch job.kind {
        case .blocklist: try await client.deleteFile(id: job.fileId, blocklist: true, search: true)
        case .cleanup: try await client.cleanupLink(fileId: job.fileId)
        case .regrab: try await client.removeAndRegrab(fileId: job.fileId)
        case .replace(let force): try await client.replaceFile(fileId: job.fileId, force: force)
        }
    }

    private static func finish(_ jobs: [ReplaceJob], _ results: [ReplacePlan.Result],
                               tokens: [SearchTarget: Int], store: DetailStore) {
        for (job, result) in zip(jobs, results) {
            let state: SearchActivity
            switch result {
            case .done: state = .searched
            case .slow: state = .stillSearching
            case .failed: state = .failed
            case .stood: state = .nothingNew
            }
            for target in job.targets {
                if let token = tokens[target] { store.searchActivity.finish(target, token: token, state) }
            }
        }
    }

    private static func activity(_ app: AppModel) -> ToastAction {
        ToastAction(label: "Activity") { app.tab = .activity }
    }
}
