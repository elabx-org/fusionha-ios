import Foundation

// MARK: - Release-group blocks (mislabel guard, fusionha 0.4.166-0.4.174)
// Routes are `integrations.manage`-gated: without it every read is a 403.

public struct ReleaseGroupBlock: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let group: String
    public let scope: String
    public let mediaItemId: Int?
    public let itemTitle: String?
    /// `mislabeled_resolution` or `manual`.
    public let reason: String?
    public let note: String?
    public let createdBy: String?
    public let createdAt: String?
}

public struct ReleaseGroupPrompt: Decodable, Sendable, Hashable {
    /// Whether to offer "Block release group?" after this proven fake.
    public let shouldPrompt: Bool
    public let decision: String?
    public let snoozeUntil: String?
}

public struct ReleaseGroupEvidence: Decodable, Sendable, Hashable {
    public struct OtherTitle: Decodable, Sendable, Hashable { public let title: String }
    public let group: String
    public let mediaItemId: Int
    public let itemTitle: String?
    public let mislabeledCount: Int
    public let probedCount: Int
    public let otherTitles: [OtherTitle]
    public let prompt: ReleaseGroupPrompt
}

struct ReleaseGroupBlockCreate: Encodable {
    let group: String
    let scope: String
    let mediaItemId: Int?
    let reason: String
    let createCustomFormat: Bool
    let source: String
}

struct PromptDecisionCreate: Encodable {
    let group: String
    let mediaItemId: Int
    let decision: String
}

extension APIClient {
    public func releaseGroupEvidence(group: String, mediaItemId: Int) async throws -> ReleaseGroupEvidence {
        try await get("/api/v1/release-groups/evidence", query: [
            URLQueryItem(name: "group", value: group),
            URLQueryItem(name: "media_item_id", value: "\(mediaItemId)"),
        ])
    }

    /// "Skip <group> for <title>" (`item`) or "Skip <group> everywhere" (`global`).
    public func blockReleaseGroup(_ group: String, scope: HeldCopy.BlockScope, mediaItemId: Int,
                                  createCustomFormat: Bool) async throws -> ReleaseGroupBlock {
        precondition(scope != .release, "Only this release is a prompt decision, not a block")
        return try await send("POST", "/api/v1/release-groups/blocks", body: ReleaseGroupBlockCreate(
            group: group, scope: scope.rawValue, mediaItemId: scope == .item ? mediaItemId : nil,
            reason: "mislabeled_resolution", createCustomFormat: createCustomFormat, source: "prompt"))
    }

    /// Settings › Quality › Blocklist: every release-group block.
    public func releaseGroupBlocks() async throws -> [ReleaseGroupBlock] {
        try await get("/api/v1/release-groups/blocks")
    }

    /// A manual block from Settings: everywhere, or for one title.
    public func addReleaseGroupBlock(_ group: String, mediaItemId: Int?, note: String?) async throws -> ReleaseGroupBlock {
        try await sendJSON("POST", "/api/v1/release-groups/blocks", .object([
            "group": .string(group), "scope": .string(mediaItemId == nil ? "global" : "item"),
            "media_item_id": mediaItemId.map { .int($0) } ?? .null, "reason": .string("manual"),
            "note": note.map { .string($0) } ?? .null, "source": .string("settings"),
        ]))
    }

    public func deleteReleaseGroupBlock(id: Int) async throws {
        try await sendJSON("DELETE", "/api/v1/release-groups/blocks/\(id)")
    }

    /// "Only this release" or "Not now" (30 days).
    public func releaseGroupPromptDecision(_ group: String, mediaItemId: Int, notNow: Bool) async throws {
        let _: ReleaseGroupPrompt = try await send("POST", "/api/v1/release-groups/prompt-decisions", body: PromptDecisionCreate(
            group: group, mediaItemId: mediaItemId, decision: notNow ? "not_now" : "only_release"))
    }
}
