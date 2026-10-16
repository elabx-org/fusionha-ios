import ActivityKit
import Foundation
import FusionhaKit

/// One aggregate Live Activity for the whole queue (not one per download),
/// which keeps us inside Apple's update budget. The content state is what the
/// approved "Live Activity redesign" draws, and its JSON (snake_case) is the
/// shape asked of fusionha for server pushes (handover doc, 2026-10-15), so a
/// push and the app's own updates decode the same way.
struct DownloadsActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Mode: String, Codable, Hashable {
            /// Something is moving: counts, speed, the two nearest to done.
            case downloading
            /// Nothing moves; held downloads wait on you.
            case held
            /// A stalled or failed download leads, in red.
            case problem
            /// One symlink (decypharr) job: its steps, not a percent.
            case steps
            /// The last import gets a moment.
            case imported
            /// An upgrade landed.
            case upgraded
            /// The queue is clear.
            case done
        }

        struct Row: Codable, Hashable {
            var downloadId: Int
            var mediaItemId: Int
            var title: String
            /// Episode label or year.
            var sub: String?
            /// `4K`, `Extended · HD`.
            var version: String
            /// 0–1, or nil for a phase job with no bytes.
            var fraction: Double?
            var posterUrl: URL?

            enum CodingKeys: String, CodingKey {
                case downloadId = "download_id", mediaItemId = "media_item_id", title, sub, version, fraction
                case posterUrl = "poster_url"
            }
        }

        struct Held: Codable, Hashable {
            var mediaItemId: Int
            var title: String
            var count: Int
            var reason: String
            var downloadIds: [Int]
            /// `4K`, `HD`; nil on activities started by older builds.
            var version: String? = nil
            var posterUrl: URL? = nil

            enum CodingKeys: String, CodingKey {
                case mediaItemId = "media_item_id", title, count, reason, downloadIds = "download_ids", version
                case posterUrl = "poster_url"
            }
        }

        struct Steps: Codable, Hashable {
            var labels: [String]
            var done: Int
            var current: String?
            /// "12/40" while linking; nil otherwise or from older builds.
            var detail: String? = nil
        }

        struct Event: Codable, Hashable {
            var mediaItemId: Int
            var downloadId: Int?
            var title: String
            var version: String
            var detail: String?
            var line2: String?

            enum CodingKeys: String, CodingKey {
                case mediaItemId = "media_item_id", downloadId = "download_id", title, version, detail, line2
            }
        }

        var mode: Mode
        var downloading: Int
        var needYou: Int
        var bps: Double?
        var etaSeconds: Int?
        var rows: [Row]
        var held: [Held]
        var steps: Steps?
        var event: Event?
        /// Unix seconds; "updated 3m ago" once the activity is stale.
        var updatedAt: Double

        enum CodingKeys: String, CodingKey {
            case mode, downloading, needYou = "need_you", bps, etaSeconds = "eta_seconds", rows, held, steps, event
            case updatedAt = "updated_at"
        }
    }
}

extension DownloadsActivityAttributes.ContentState {
    /// The same state with the volatile numbers left out, so the app only
    /// sends an update when something a person would notice changed.
    var settled: Self {
        var copy = self
        copy.updatedAt = 0
        copy.bps = bps.map { ($0 / 500_000).rounded() * 500_000 }
        copy.etaSeconds = etaSeconds.map { ($0 / 30) * 30 }
        copy.rows = rows.map { var r = $0; r.fraction = r.fraction.map { ($0 * 100).rounded() / 100 }; return r }
        return copy
    }

    /// The App Group file the app writes a small poster to, for the activity.
    static func posterFile(mediaItemId: Int) -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.org.elabx.fusionha")?
            .appendingPathComponent("live-activity", isDirectory: true)
            .appendingPathComponent("poster-\(mediaItemId).jpg")
    }

    /// The shared-keychain copy: a build re-signed without the App Group has
    /// no shared container, and the keychain is all both processes see.
    static func posterAccount(mediaItemId: Int) -> String { "la-poster-\(mediaItemId)" }

    static func posterData(mediaItemId: Int) -> Data? {
        posterFile(mediaItemId: mediaItemId).flatMap { try? Data(contentsOf: $0) }
            ?? SharedKeychain.read(posterAccount(mediaItemId: mediaItemId))
    }

    /// Where a poster can be found from this process, for Account › Live
    /// Activity's diagnostics: the App Group file, then each keychain group.
    static func posterReport(mediaItemId: Int) -> String {
        let file = posterFile(mediaItemId: mediaItemId)
        let fileState = file == nil ? "no App Group" : (FileManager.default.fileExists(atPath: file!.path) ? "file ok" : "no file")
        return "\(fileState) · keychain \(SharedKeychain.report(posterAccount(mediaItemId: mediaItemId)))"
    }

    /// The Lock Screen side writes what it found here (once per poster per
    /// process), so the app can show why a tile stayed blank.
    static let posterSeenAccount = "la-poster-seen"

    static func recordPosterSeen(mediaItemId: Int, found: Bool) {
        var seen = (SharedKeychain.read(posterSeenAccount).flatMap { try? JSONDecoder().decode([String: String].self, from: $0) }) ?? [:]
        let line = (found ? "shown · " : "missing · ") + posterReport(mediaItemId: mediaItemId)
        guard seen["\(mediaItemId)"] != line else { return }
        seen["\(mediaItemId)"] = line
        if seen.count > 12 { seen = Dictionary(uniqueKeysWithValues: seen.sorted { $0.key > $1.key }.prefix(12).map { ($0.key, $0.value) }) }
        if let data = try? JSONEncoder().encode(seen) { SharedKeychain.write(data, posterSeenAccount) }
    }

    static func posterSeen() -> [String: String] {
        (SharedKeychain.read(posterSeenAccount).flatMap { try? JSONDecoder().decode([String: String].self, from: $0) }) ?? [:]
    }
}
