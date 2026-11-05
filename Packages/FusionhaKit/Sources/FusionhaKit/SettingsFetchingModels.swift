import Foundation

// Models for the native Settings panels under "Fetching" and "System":
// Root Folders, Download Clients (Indexers: IndexerSettingsModels.swift), Connect, Notifications,
// Connections, Public access, System, Database, Backup and Logs.
// Read shapes decode with the client's convertFromSnakeCase decoder;
// write bodies are built as `SettingsJSON` objects so explicit `null`s
// (clear a field) and snake_case keys go over the wire exactly as the web sends them.

// MARK: JSON write bodies

/// A JSON value for request bodies. Keys are sent verbatim (snake_case, as the web does).
public enum SettingsJSON: Sendable, Hashable, Encodable,
    ExpressibleByNilLiteral, ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral,
    ExpressibleByFloatLiteral, ExpressibleByStringLiteral, ExpressibleByArrayLiteral,
    ExpressibleByDictionaryLiteral {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([SettingsJSON])
    case object([String: SettingsJSON])

    public init(nilLiteral: ()) { self = .null }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(integerLiteral value: Int) { self = .int(value) }
    public init(floatLiteral value: Double) { self = .double(value) }
    public init(stringLiteral value: String) { self = .string(value) }
    public init(arrayLiteral elements: SettingsJSON...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, SettingsJSON)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { _, last in last }))
    }

    /// `null` when nil, else the value.
    public static func optional(_ value: Int?) -> SettingsJSON { value.map(SettingsJSON.int) ?? .null }
    public static func optional(_ value: String?) -> SettingsJSON { value.map(SettingsJSON.string) ?? .null }
    public static func ints(_ values: [Int]) -> SettingsJSON { .array(values.map(SettingsJSON.int)) }
    public static func optionalInts(_ values: [Int]?) -> SettingsJSON { values.map(ints) ?? .null }

    public typealias Key = String
    public typealias Value = SettingsJSON
    public typealias ArrayLiteralElement = SettingsJSON

    private struct FieldKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .null:
            var c = encoder.singleValueContainer(); try c.encodeNil()
        case .bool(let v):
            var c = encoder.singleValueContainer(); try c.encode(v)
        case .int(let v):
            var c = encoder.singleValueContainer(); try c.encode(v)
        case .double(let v):
            var c = encoder.singleValueContainer(); try c.encode(v)
        case .string(let v):
            var c = encoder.singleValueContainer(); try c.encode(v)
        case .array(let values):
            var c = encoder.unkeyedContainer()
            for value in values { try c.encode(value) }
        case .object(let fields):
            var c = encoder.container(keyedBy: FieldKey.self)
            for (key, value) in fields { try c.encode(value, forKey: FieldKey(stringValue: key)) }
        }
    }
}

/// `{ok, message}` from a `POST …/test` connection probe.
public struct ConnectionTestResult: Decodable, Sendable, Hashable {
    public let ok: Bool
    public let message: String
    /// Download clients only: the detected client version and its categories.
    public let version: String?
    public let categories: [String]?

    public init(ok: Bool, message: String, version: String? = nil, categories: [String]? = nil) {
        self.ok = ok
        self.message = message
        self.version = version
        self.categories = categories
    }
}

// MARK: Root folders

public enum ImportMode: String, CaseIterable, Sendable, Identifiable {
    case hardlink = "HARDLINK", symlink = "SYMLINK", copy = "COPY", move = "MOVE"
    public var id: String { rawValue }
    /// `Hardlink` / `Symlink` / `Copy` / `Move`.
    public var label: String { String(rawValue.prefix(1)) + rawValue.dropFirst().lowercased() }
}

/// `GET /api/v1/rootfolders` with free space and the tracked footprint.
public struct RootFolderInfo: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let path: String
    public let defaultImportMode: String
    public let freeSpace: Int?
    public let totalSpace: Int?
    public let usedSpace: Int?
    public let accessible: Bool?
    public let trackedEditions: Int?
    public let trackedSize: Int?
    public let defaultFor: [AddDefaultSlot]?

    public var online: Bool { accessible != false }
    public var importMode: ImportMode { ImportMode(rawValue: defaultImportMode.uppercased()) ?? .hardlink }

    /// The tier a root holds, inferred from its path like the web (`/movies-4k` → 4K).
    public var inferredTier: QualityTier {
        path.range(of: "4k|2160|uhd", options: [.regularExpression, .caseInsensitive]) != nil ? .uhd : .hd
    }

    /// `anime` / `series` / `movie`, inferred from the path like the web.
    public var inferredKind: String {
        if path.range(of: "anime", options: .caseInsensitive) != nil { return "anime" }
        return path.range(of: "tv|series|anime|show", options: [.regularExpression, .caseInsensitive]) != nil
            ? "series" : "movie"
    }
}

// MARK: Download clients

public struct DownloadClientInfo: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let `protocol`: String
    public let host: String
    public let port: Int
    public let useSsl: Bool?
    public let urlBase: String?
    public let username: String?
    public let passwordConfigured: Bool?
    public let enable: Bool?
    public let priority: Int?
    public let recentPriority: Int?
    public let olderPriority: Int?
    public let removeCompleted: Bool?
    public let removeFailed: Bool?
    public let postImportCategory: String?
    public let categoryMap: [String: String]?
    /// The client's file-check capabilities (the list carries them too).
    public let capabilities: ClientCapabilities?

    public var isTorrent: Bool { `protocol` == "TORRENT" }
}
