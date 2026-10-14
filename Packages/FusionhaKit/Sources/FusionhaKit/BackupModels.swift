import Foundation

// MARK: Backup

public struct BackupConfig: Decodable, Sendable, Hashable {
    public let enabled: Bool
    public let intervalHours: Int
    public let retention: Int
    public let folder: String
    public let available: Bool?
    public let backend: String?
}

public struct BackupRecord: Decodable, Sendable, Identifiable, Hashable {
    public let id: String
    public let sizeBytes: Int
    public let createdAt: String
    public let kind: String
    public let appVersion: String?
    // Secrets at rest (fusionha 0.4.188), from the archive's manifest. A backup
    // made before encryption has none of these.
    public let keyFingerprint: String?
    /// The archive holds the secret key: downloading it needs your password.
    public let keyIncluded: Bool?
    public let encrypted: Bool?
}

public struct BackupCreateResult: Decodable, Sendable {
    public let backup: BackupRecord
}
