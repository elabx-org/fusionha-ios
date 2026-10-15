import Foundation

/// The A1 decision facts for one pending request (`GET /requests/triage`,
/// approvers only).
public struct RequestTriage: Decodable, Sendable, Hashable {
    public struct TrackRecord: Decodable, Sendable, Hashable {
        public let requests30d: Int
        public let approved30d: Int
        public let declined30d: Int
        public let trusted: Bool

        public init(requests30d: Int = 0, approved30d: Int = 0, declined30d: Int = 0, trusted: Bool = false) {
            self.requests30d = requests30d
            self.approved30d = approved30d
            self.declined30d = declined30d
            self.trusted = trusted
        }

        // `convertFromSnakeCase` reads `requests_30d` as `requests30d`.
        enum CodingKeys: String, CodingKey { case requests30d, approved30d, declined30d, trusted }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            requests30d = try c.decodeIfPresent(Int.self, forKey: .requests30d) ?? 0
            approved30d = try c.decodeIfPresent(Int.self, forKey: .approved30d) ?? 0
            declined30d = try c.decodeIfPresent(Int.self, forKey: .declined30d) ?? 0
            trusted = try c.decodeIfPresent(Bool.self, forKey: .trusted) ?? false
        }
    }

    public struct Demand: Decodable, Sendable, Hashable {
        public let count: Int
        public let people: [RequestPerson]
        public init(count: Int = 1, people: [RequestPerson] = []) {
            self.count = count
            self.people = people
        }
    }

    /// What a plain approve adds for one requested tier ("your usual setup").
    public struct Version: Decodable, Sendable, Hashable {
        public let tier: QualityTier
        public let configured: Bool
        public let existing: Bool?
        public let monitored: Bool?
        public let rootFolderId: Int?
        public let rootPath: String?
        public let qualityProfileId: Int?
        public let profileName: String?
        public let estimateBytes: Double?

        public init(tier: QualityTier, configured: Bool, existing: Bool? = false, monitored: Bool? = true,
                    rootFolderId: Int? = nil, rootPath: String? = nil, qualityProfileId: Int? = nil,
                    profileName: String? = nil, estimateBytes: Double? = nil) {
            self.tier = tier
            self.configured = configured
            self.existing = existing
            self.monitored = monitored
            self.rootFolderId = rootFolderId
            self.rootPath = rootPath
            self.qualityProfileId = qualityProfileId
            self.profileName = profileName
            self.estimateBytes = estimateBytes
        }
    }

    /// One filesystem the approve writes to. `freeAfterBytes` may be negative.
    public struct Disk: Decodable, Sendable, Hashable {
        public let rootPaths: [String]
        public let totalBytes: Double?
        public let freeBytes: Double?
        public let neededBytes: Double
        public let freeAfterBytes: Double?
        public let estimateComplete: Bool?

        public init(rootPaths: [String], totalBytes: Double? = nil, freeBytes: Double? = nil, neededBytes: Double = 0,
                    freeAfterBytes: Double? = nil, estimateComplete: Bool? = true) {
            self.rootPaths = rootPaths
            self.totalBytes = totalBytes
            self.freeBytes = freeBytes
            self.neededBytes = neededBytes
            self.freeAfterBytes = freeAfterBytes
            self.estimateComplete = estimateComplete
        }
    }

    public struct FourK: Decodable, Sendable, Hashable {
        /// available · tracked · unseen · unchecked
        public let state: String
        public let bestQuality: String?
        public let bestReleaseName: String?
        public let indexers: Int?

        public init(state: String, bestQuality: String? = nil, bestReleaseName: String? = nil, indexers: Int? = 0) {
            self.state = state
            self.bestQuality = bestQuality
            self.bestReleaseName = bestReleaseName
            self.indexers = indexers
        }
    }

    public struct Release: Decodable, Sendable, Hashable {
        /// out · upcoming · unknown
        public let state: String
        public let label: String
        public let availableFrom: String?

        public init(state: String, label: String, availableFrom: String? = nil) {
            self.state = state
            self.label = label
            self.availableFrom = availableFrom
        }
    }

    public let requestId: Int
    public let itemId: Int?
    public let isAnime: Bool?
    public let runtimeMinutes: Int?
    public let trackRecord: TrackRecord
    public let demand: Demand
    public let versions: [Version]
    public let disks: [Disk]
    public let lowSpace: Bool
    public let fourK: FourK
    public let release: Release
    public let metaPending: Bool

    public init(requestId: Int, itemId: Int? = nil, isAnime: Bool? = nil, runtimeMinutes: Int? = nil,
                trackRecord: TrackRecord = TrackRecord(), demand: Demand = Demand(), versions: [Version] = [],
                disks: [Disk] = [], lowSpace: Bool = false, fourK: FourK = FourK(state: "unchecked"),
                release: Release = Release(state: "unknown", label: "—"), metaPending: Bool = false) {
        self.requestId = requestId
        self.itemId = itemId
        self.isAnime = isAnime
        self.runtimeMinutes = runtimeMinutes
        self.trackRecord = trackRecord
        self.demand = demand
        self.versions = versions
        self.disks = disks
        self.lowSpace = lowSpace
        self.fourK = fourK
        self.release = release
        self.metaPending = metaPending
    }

    enum CodingKeys: String, CodingKey {
        case requestId, itemId, isAnime, runtimeMinutes, trackRecord, demand, versions, disks, lowSpace, fourK, release, metaPending
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        requestId = try c.decode(Int.self, forKey: .requestId)
        itemId = try c.decodeIfPresent(Int.self, forKey: .itemId)
        isAnime = try c.decodeIfPresent(Bool.self, forKey: .isAnime)
        runtimeMinutes = try c.decodeIfPresent(Int.self, forKey: .runtimeMinutes)
        trackRecord = try c.decodeIfPresent(TrackRecord.self, forKey: .trackRecord) ?? TrackRecord()
        demand = try c.decodeIfPresent(Demand.self, forKey: .demand) ?? Demand()
        versions = try c.decodeIfPresent([Version].self, forKey: .versions) ?? []
        disks = try c.decodeIfPresent([Disk].self, forKey: .disks) ?? []
        lowSpace = try c.decodeIfPresent(Bool.self, forKey: .lowSpace) ?? false
        fourK = try c.decodeIfPresent(FourK.self, forKey: .fourK) ?? FourK(state: "unchecked")
        release = try c.decodeIfPresent(Release.self, forKey: .release) ?? Release(state: "unknown", label: "—")
        metaPending = try c.decodeIfPresent(Bool.self, forKey: .metaPending) ?? false
    }
}

/// `POST /requests/bulk`: one decision over many requests; each row commits on its own.
public struct RequestBulkBody: Encodable, Sendable {
    public let ids: [Int]
    /// approve · decline · defer
    public let action: String
    public let reason: String?
    public let search: Bool

    public init(ids: [Int], action: String, reason: String? = nil, search: Bool = false) {
        self.ids = ids
        self.action = action
        self.reason = reason
        self.search = search
    }
}

public struct RequestBulkResult: Decodable, Sendable {
    public struct Row: Decodable, Sendable {
        public let id: Int
        public let ok: Bool
        public let error: String?
    }
    public let results: [Row]
}

extension APIClient {
    /// Triage facts for up to 50 pending requests.
    public func requestTriage(ids: [Int]) async throws -> [RequestTriage] {
        guard !ids.isEmpty else { return [] }
        return try await get("/api/v1/requests/triage", query: ids.map { URLQueryItem(name: "ids", value: String($0)) })
    }

    public func bulkDecide(_ body: RequestBulkBody) async throws -> RequestBulkResult {
        try await send("POST", "/api/v1/requests/bulk", body: body)
    }
}
