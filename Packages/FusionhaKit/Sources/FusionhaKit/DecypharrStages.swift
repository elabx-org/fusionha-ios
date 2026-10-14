import Foundation

/// Which of decypharr's config-gated stages run on this install
/// (`GET/PUT /api/v1/settings/decypharr-stages`, fusionha 0.4.189). decypharr
/// doesn't expose its own `skip_post_symlink_probe` / `skip_ffprobe_validation`,
/// so these mirror it for the queue card's stage rail: a skipped stage is drawn
/// greyed and left out of the ring. Display-only; admin. Defaults: probing
/// off, validating on.
public struct DecypharrStages: Codable, Sendable, Hashable {
    public var probing: Bool
    public var validating: Bool

    public init(probing: Bool, validating: Bool) {
        self.probing = probing
        self.validating = validating
    }
}

extension APIClient {
    public func decypharrStages() async throws -> DecypharrStages {
        try await get("/api/v1/settings/decypharr-stages")
    }

    public func updateDecypharrStages(_ stages: DecypharrStages) async throws -> DecypharrStages {
        try await send("PUT", "/api/v1/settings/decypharr-stages", body: stages)
    }
}
