import AppIntents
import Foundation
import FusionhaKit

/// "Search again" on the Live Activity's problem state: blocklists the stuck
/// release and searches for another, without opening the app (the queue
/// card's Remove → blocklist + search).
struct LiveActivitySearchAgainIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Search again"
    static var description = IntentDescription("Blocklist this release and search for another.")

    @Parameter(title: "Download") var downloadId: Int

    init() {}

    init(downloadId: Int) {
        self.downloadId = downloadId
    }

    func perform() async throws -> some IntentResult {
        guard let client = CredentialStore.load()?.client() else { return .result() }
        try await client.removeQueueItem(id: downloadId, blocklist: true, search: true)
        return .result()
    }
}
