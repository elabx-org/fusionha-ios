import Foundation

extension APIClient {
    /// `GET /api/v1/library/setups`: the caller's active and recently finished setups.
    public func setups() async throws -> TitleSetupList {
        try await get("/api/v1/library/setups")
    }
}
