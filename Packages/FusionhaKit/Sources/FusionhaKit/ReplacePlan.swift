import Foundation

/// What a Fix-mode Replace sends for each file, one request per file so the
/// files run together (owner-approved "Replace without waiting", 2026-11-08).
/// The same choices as `ManageFilesModel.replace`: a file being blocklisted is
/// deleted with its release blocklisted and a search; an unmonitored file
/// only has its dead link cleaned up; a monitored file gone from disk goes
/// through remove-and-regrab; a damaged one is force-replaced.
public struct ReplaceJob: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case blocklist, cleanup, regrab
        case replace(force: Bool)

        /// The status that means "nothing was done, on purpose" (mount not
        /// ready, the link recovered), not a failure.
        public var standDownStatus: Int? {
            switch self {
            case .blocklist: return nil
            case .cleanup, .regrab: return 422
            case .replace: return 409
            }
        }
    }

    public let fileId: Int
    public let kind: Kind
    /// The searches this job starts, for the title page's in-place state.
    public let targets: [SearchTarget]

    public var searches: Bool { kind != .cleanup }
}

public enum ReplacePlan {
    public static func jobs(_ items: [ManagedFileItem], blocklisting: Set<Int>, detail: ItemDetail) -> [ReplaceJob] {
        items.map { item in
            let kind: ReplaceJob.Kind
            if blocklisting.contains(item.id) { kind = .blocklist }
            else if !item.monitored { kind = .cleanup }
            else if item.absent { kind = .regrab }
            else { kind = .replace(force: item.unreadable) }
            let targets: [SearchTarget]
            if kind == .cleanup {
                targets = []
            } else if detail.isSeries {
                targets = ManageEpisodes.episodeIds([item], detail: detail)
                    .map { .episodeVersion(episode: $0, version: item.row.versionId) }
            } else {
                targets = [.version(item.row.versionId)]
            }
            return ReplaceJob(fileId: item.id, kind: kind, targets: targets)
        }
    }

    /// One job's result.
    public enum Result: Equatable, Sendable { case done, stood, failed, slow }

    /// A transport error that means the server is probably still working:
    /// the app stopped waiting, the request may well have gone through.
    public static func isSlow(_ error: Error) -> Bool {
        guard let url = error as? URLError else { return false }
        return [.timedOut, .networkConnectionLost].contains(url.code)
    }

    public static func result(of error: Error, kind: ReplaceJob.Kind) -> Result {
        if isSlow(error) { return .slow }
        if let status = kind.standDownStatus, case APIError.http(status, _) = error { return .stood }
        return .failed
    }

    /// The toast once every job has answered.
    public struct Summary: Equatable, Sendable {
        public let message: String
        public let isError: Bool
        public let pointsToActivity: Bool
    }

    public static func summary(_ results: [Result], searched: Int) -> Summary {
        let failed = results.filter { $0 == .failed }.count
        let slow = results.filter { $0 == .slow }.count
        let stood = results.filter { $0 == .stood }.count
        if failed > 0 {
            return Summary(message: "Couldn’t replace \(failed == 1 ? "1 file" : "\(failed) files"). Try again.",
                           isError: true, pointsToActivity: false)
        }
        if slow > 0 {
            return Summary(message: "Still searching on the server. Activity shows the result.",
                           isError: false, pointsToActivity: true)
        }
        var parts: [String] = []
        if searched > 0 {
            parts.append("Searched for \(searched == 1 ? "a new copy" : "\(searched) new copies").")
        } else if results.contains(.done) {
            parts.append("Dead link cleared.")
        }
        if stood > 0 { parts.append("Mount not ready or the link recovered, so nothing was deleted.") }
        return Summary(message: parts.joined(separator: " "), isError: false, pointsToActivity: searched > 0)
    }
}
