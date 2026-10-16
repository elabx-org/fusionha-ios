import Foundation

// Settings › Quality › Custom Formats, native (web `CustomFormatsPanel`,
// `CfConditionBlocks`, `CfLiveTester`, `CustomFormatTesterPanel`;
// `lib/api/config.ts` customFormatsApi + `lib/api/cf-tester.ts`).

// MARK: Models

/// One condition of a custom format (`CustomFormatSpecIn`). Stored specs
/// default `required` to true (arr semantics) and `negate` to false.
public struct CustomFormatSpec: Decodable, Sendable, Hashable {
    public var specType: String
    public var value: String
    public var negate: Bool
    public var required: Bool

    public init(specType: String, value: String, negate: Bool = false, required: Bool = false) {
        self.specType = specType
        self.value = value
        self.negate = negate
        self.required = required
    }

    private enum CodingKeys: String, CodingKey { case specType, value, negate, required }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        specType = try c.decode(String.self, forKey: .specType)
        value = (try c.decodeIfPresent(String.self, forKey: .value)) ?? ""
        negate = (try c.decodeIfPresent(Bool.self, forKey: .negate)) ?? false
        required = (try c.decodeIfPresent(Bool.self, forKey: .required)) ?? true
    }

    /// The wire body for one condition.
    public var json: SettingsJSON {
        .object(["spec_type": .string(specType), "value": .string(value),
                 "negate": .bool(negate), "required": .bool(required)])
    }
}

/// `CustomFormatRead`.
public struct CustomFormatInfo: Decodable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let name: String
    public let specifications: [CustomFormatSpec]
    public let includeWhenRenaming: Bool?
    /// `manual` · `trash` · `arr` · `preset`.
    public let source: String?
    public let trashId: String?
    /// `movie` · `series` · `anime`, nil on legacy rows.
    public let mediaKind: String?
    public let isOverride: Bool?

    public var provenance: String { source ?? "manual" }
}

/// A quality profile's id, name and custom-format scores: enough for "used in
/// N profiles" and the preset deploy target check.
public struct ProfileScoringSummary: Decodable, Sendable, Hashable, Identifiable {
    public struct Score: Decodable, Sendable, Hashable {
        public let customFormatId: Int
        public let score: Int?
    }

    public let id: Int
    public let name: String
    public let mediaKind: String?
    public let formatScores: [Score]?
    public let deployedFromPresetId: Int?
    public let inUse: Int?
}

/// `BulkResult` from `POST /customformats/bulk-delete`.
public struct CustomFormatBulkResult: Decodable, Sendable {
    public struct Failure: Decodable, Sendable {
        public let id: Int?
        public let detail: String?
    }

    public let affected: Int
    public let errors: [Failure]?

    /// `bulkDeleteToast`: "Deleted N custom formats" (· "M in use, not deleted").
    public var message: String {
        let skipped = errors?.count ?? 0
        let noun = "custom format" + (affected == 1 ? "" : "s")
        return skipped == 0 ? "Deleted \(affected) \(noun)" : "Deleted \(affected) \(noun) · \(skipped) in use, not deleted"
    }

    public var hadSkips: Bool { (errors?.count ?? 0) > 0 }
}

// MARK: Tester models (`CFTestResponse`)

public struct CFTestParsed: Decodable, Sendable, Hashable {
    public let quality: String
    public let resolution: Int?
    public let source: String?
    public let releaseGroup: String?
    public let edition: String?
    public let languages: [String]?

    /// `ParsedChips`: quality label · `1080p` · source · group · edition · languages.
    public var chips: [String] {
        var out = [DetailText.quality(quality)]
        if let resolution, resolution > 0 { out.append("\(resolution)p") }
        out.append(source ?? "")
        out.append(releaseGroup ?? "")
        out.append(edition ?? "")
        out.append(contentsOf: languages ?? [])
        return out.filter { !$0.isEmpty }
    }
}

public struct CFTestMatch: Decodable, Sendable, Hashable {
    public let name: String
    public let score: Int
}

public struct CFTestResult: Decodable, Sendable, Hashable {
    public let title: String
    public let parsed: CFTestParsed
    public let matched: [CFTestMatch]
    public let total: Int
    /// `grab` · `upgrade` · `reject`.
    public let action: String
    public let accepted: Bool
    public let reason: String?
    public let best: Bool

    /// Grab / Upgrade / Reject.
    public var verdictLabel: String { accepted ? (action == "upgrade" ? "Upgrade" : "Grab") : "Reject" }
    public var matchedTotal: Int { matched.reduce(0) { $0 + $1.score } }
}

public struct CFTestResponse: Decodable, Sendable {
    public let results: [CFTestResult]
}

public struct RecentReleases: Decodable, Sendable {
    public let source: String
    public let titles: [String]
}

/// The three feeds "Load test data from the app" pulls seed titles from.
public enum RecentReleaseSource: String, CaseIterable, Sendable {
    case search, rss, grab

    public var label: String {
        switch self {
        case .search: return "Last interactive search"
        case .rss: return "Recent RSS batch"
        case .grab: return "Grab history"
        }
    }
}

/// ISO 639-1 codes the backend maps for the tester's "Original language".
public enum CFOriginalLanguages {
    public static let all: [(code: String, name: String)] = [
        ("en", "English"), ("ja", "Japanese"), ("fr", "French"), ("de", "German"), ("es", "Spanish"),
        ("it", "Italian"), ("ko", "Korean"), ("zh", "Chinese"), ("pt", "Portuguese"), ("ru", "Russian"),
        ("hi", "Hindi"), ("nl", "Dutch"), ("sv", "Swedish"), ("no", "Norwegian"), ("da", "Danish"),
        ("fi", "Finnish"), ("pl", "Polish"), ("el", "Greek"), ("tr", "Turkish"),
    ]
}

// MARK: Endpoints

extension APIClient {
    public func customFormats() async throws -> [CustomFormatInfo] { try await get("/api/v1/customformats") }

    public func profileScoringSummaries() async throws -> [ProfileScoringSummary] {
        try await get("/api/v1/qualityprofiles")
    }

    /// Create (`id == nil`) or replace a custom format with the editor's fields.
    public func saveCustomFormat(id: Int?, name: String, mediaKind: String, includeWhenRenaming: Bool,
                                 specifications: [CustomFormatSpec]) async throws -> CustomFormatInfo {
        let body: SettingsJSON = .object([
            "name": .string(name), "media_kind": .string(mediaKind),
            "include_when_renaming": .bool(includeWhenRenaming),
            "specifications": .array(specifications.map(\.json)),
        ])
        if let id { return try await sendJSON("PUT", "/api/v1/customformats/\(id)", body) }
        return try await sendJSON("POST", "/api/v1/customformats", body)
    }

    public func deleteCustomFormat(id: Int) async throws {
        try await sendJSON("DELETE", "/api/v1/customformats/\(id)")
    }

    public func bulkDeleteCustomFormats(ids: [Int]) async throws -> CustomFormatBulkResult {
        try await sendJSON("POST", "/api/v1/customformats/bulk-delete", .object(["ids": .ints(ids)]))
    }

    /// `POST /customformats/test`: parse → score → decision against one profile, persisting nothing.
    public func testCustomFormats(titles: [String], qualityProfileId: Int,
                                  originalLanguage: String?) async throws -> CFTestResponse {
        try await sendJSON("POST", "/api/v1/customformats/test", .object([
            "titles": .array(titles.map(SettingsJSON.string)),
            "quality_profile_id": .int(qualityProfileId),
            "original_language": .optional(originalLanguage),
        ]))
    }

    public func recentReleases(source: RecentReleaseSource, itemId: Int? = nil) async throws -> RecentReleases {
        var query = [URLQueryItem(name: "source", value: source.rawValue)]
        if let itemId { query.append(URLQueryItem(name: "item_id", value: String(itemId))) }
        return try await get("/api/v1/releases/recent", query: query)
    }
}
