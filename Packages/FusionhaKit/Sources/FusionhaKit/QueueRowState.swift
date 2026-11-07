import Foundation

/// Where one queue download really stands: the one answer the queue's
/// section, its row words, its badge and the pipeline strip's counts all
/// read, so they never disagree.
///
/// It follows the web's `queueCardGroup` (fusionha `queue-groups.ts`) with
/// two corrections for what the native `/api/v1/queue` actually sends. That
/// route serves stored state: `status` stays `queued` for the whole download
/// (nothing on the server moves a row to `downloading`) and `sizeleft` is
/// always 0. So:
/// * a row the client has made progress on is downloading, whatever `status`
///   says, and only a row at 0% is still waiting in line;
/// * a byte download at 100% that fusionha hasn't picked up yet is finished
///   and waiting to import, not "Downloading 100%" in Up next.
public enum QueueRowState: Equatable, Sendable {
    /// Paused until the owner decides (Manual Import).
    case held
    /// The server says it needs a look (no release left, stuck).
    case stuck
    /// A decypharr job that stopped for good short of `complete`.
    case failed
    /// fusionha is importing it (or decypharr finished and the import runs).
    case importing
    /// The download finished; the import poll hasn't picked it up yet.
    case awaitingImport
    /// A decypharr job in a non-byte stage (parsing, linking, caching…),
    /// including an error it retries by itself.
    case processing
    /// A real transfer with progress.
    case downloading
    /// Grabbed, but the download client hasn't reported the job yet.
    case waitingForClient
    /// In line, nothing moved yet.
    case queued
}

extension QueueItem {
    /// Statuses that mean "waiting in line" (web `WAITING`).
    static let waitingStatuses: Set<String> = ["queued", "delay", "pending", "paused"]

    /// How much of the download is done, 0...1: real bytes when the server
    /// sends a remaining count, else its `progress` percent. A `sizeleft` of
    /// 0 is not evidence of a finished download (the stored-state queue
    /// never fills it in), so it never reads as 100% on its own.
    public var doneFraction: Double {
        let value: Double
        if size > 0, sizeleft > 0 {
            value = 1 - sizeleft / size
        } else {
            value = progress / 100
        }
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }

    /// `doneFraction` as a whole percent, the number the row prints.
    public var percentDone: Int { Int((doneFraction * 100).rounded()) }

    /// The client has moved any bytes for it.
    public var hasStarted: Bool { doneFraction > 0 }

    /// A byte download that reached 100%.
    public var finishedDownloading: Bool { doneFraction >= 1 }

    /// The decypharr stage plan (or, on older servers, the phase) says this
    /// job is in a non-byte stage.
    var inPhaseMode: Bool {
        if let mode = stages?.mode { return mode == "phase" }
        return phase != nil && phase != "downloading"
    }

    /// Where this download stands (see `QueueRowState`).
    public var rowState: QueueRowState {
        let s = self.status.lowercased()
        if s == "held" { return .held }
        if needsAttention == true { return .stuck }
        if phaseTerminal == true, let phase, phase != "complete" { return .failed }
        if phase == "importing" || phase == "complete" || s == "completed" { return .importing }
        if phase == "queued" { return .queued }
        if inPhaseMode { return .processing }
        if finishedDownloading { return .awaitingImport }
        if warning != nil { return .waitingForClient }
        if Self.waitingStatuses.contains(s), !stalled, !hasStarted { return .queued }
        return .downloading
    }
}
