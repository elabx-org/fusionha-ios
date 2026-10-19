import Foundation
import FusionhaKit

/// The queue's pipeline strip (web `pipeline-model.ts`). Idle collapses to one
/// line; running sums the decypharr stages across jobs plus fusionha's own
/// Importing. "Full downloads: N · MB/s" counts genuine byte transfers only.
struct QueuePipelineModel {
    static let stages = ["queued", "parsing", "downloading", "processed", "linking",
                         "caching", "probing", "validating", "importing"]

    struct Column: Identifiable {
        let key: String
        let label: String
        let count: Int
        /// This install skips the stage (from the jobs' own stage plans).
        let off: Bool
        var id: String { key }
    }

    let running: Bool
    /// Jobs in flight: decypharr stages, importing and full downloads.
    let jobs: Int
    /// "1 failed at parsing" / "2 failed"; nil with no failures.
    let failed: String?
    let columns: [Column]
    let fullDownloads: Int
    /// The download ids whose bytes count toward MB/s.
    let byteIds: [Int]

    init(_ items: [QueueItem]) {
        var counts: [String: Int] = [:]
        var off = Set<String>()
        var failedItems: [QueueItem] = []
        var bytes: [Int] = []
        for item in items {
            for step in item.stages?.steps ?? [] where !step.runs { off.insert(step.key) }
            switch QueueSection.of(item) {
            case .failed:
                failedItems.append(item)
            case .importing:
                counts["importing", default: 0] += 1
            case .progress:
                let at = item.stages?.current ?? item.phase ?? "queued"
                let key = Self.stages.contains(at) ? at : (at == "complete" ? "importing" : "queued")
                counts[key, default: 0] += 1
            case .downloading where Self.isFullDownload(item) && item.warning == nil:
                bytes.append(item.id)
            default:
                break
            }
        }
        columns = Self.stages.map { key in
            let n = counts[key] ?? 0
            return Column(key: key, label: QueueStageLabel.label(key), count: n, off: off.contains(key) && n == 0)
        }
        let staged = counts.values.reduce(0, +)
        jobs = staged + bytes.count
        running = jobs > 0
        failed = Self.failedLine(failedItems)
        fullDownloads = bytes.count
        byteIds = bytes
    }

    static func isFullDownload(_ item: QueueItem) -> Bool {
        if let mode = item.stages?.mode { return mode == "bytes" }
        return item.phase == nil && item.status.lowercased() == "downloading"
    }

    static func failedLine(_ items: [QueueItem]) -> String? {
        guard !items.isEmpty else { return nil }
        let stages = Set(items.map { $0.stages?.current ?? "" })
        if stages.count == 1, let only = stages.first, !only.isEmpty {
            return "\(items.count) failed at \(QueueStageLabel.label(only).lowercased())"
        }
        return "\(items.count) failed"
    }

    /// "Last import 13:11 · Supergirl S02E12" today, else with the date.
    static func lastImportLine(_ last: QueuePipeline.LastImport?, now: Date = Date()) -> String? {
        guard let last, let at = ServerTime.parse(last.at) else { return nil }
        let when = Calendar.current.isDate(at, inSameDayAs: now)
            ? at.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
            : at.formatted(.dateTime.month(.abbreviated).day())
        let what = last.episodeLabel.map { "\(last.title) \($0)" } ?? last.title
        return "Last import \(when) · \(what)"
    }
}
