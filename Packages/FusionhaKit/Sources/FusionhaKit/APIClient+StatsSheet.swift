import Foundation

// The Library stats sheet's data sources (the web's useLibraryAttention,
// useRunAttention, useIndexersUnavailable and useOperations).
extension APIClient {
    public func libraryAttentionEntries() async throws -> [LibraryAttentionEntry] {
        let page: ItemsEnvelope<LibraryAttentionEntry> = try await get("/api/v1/library/attention")
        return page.items
    }

    public func runAttentionEntries() async throws -> [RunAttentionEntry] {
        let page: ItemsEnvelope<RunAttentionEntry> = try await get("/api/v1/system/runs/attention")
        return page.items
    }

    public func stoppedIndexers() async throws -> [UnavailableIndexer] {
        let page: ItemsEnvelope<UnavailableIndexer> = try await get("/api/v1/system/indexers/unavailable")
        return page.items
    }

    public func operationCommands() async throws -> [OperationCommand] {
        try await get("/api/v1/system/commands")
    }

    /// `POST /api/v1/system/runs/{id}/ack`: dismiss one no-grab attention row.
    public func ackRunAttention(_ runId: Int) async throws {
        let _: EmptyResponse = try await perform(request(method: "POST", path: "/api/v1/system/runs/\(runId)/ack", query: []))
    }

    /// `POST /api/v1/library/{id}/scope-mismatch/dismiss`.
    public func dismissScopeMismatch(_ itemId: Int) async throws {
        let _: EmptyResponse = try await perform(request(method: "POST", path: "/api/v1/library/\(itemId)/scope-mismatch/dismiss", query: []))
    }
}
