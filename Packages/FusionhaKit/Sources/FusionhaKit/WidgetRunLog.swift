import Foundation

/// The last timeline reload of the paged Downloads widget: how far it got and
/// how it ended. The extension writes it at every stage, so a reload the system
/// killed (memory, time) is left `running` and the next reload can say so.
public struct WidgetRunLog: Codable, Sendable, Equatable {
    public enum Outcome: String, Codable, Sendable {
        case running, ok, failed, timedOut = "timeout"
    }

    /// `auth`, `queue`, `pages`, `page`, `render`.
    public var stage: String
    public var page: String
    public var outcome: Outcome
    public var error: String?
    public var started: Date
    public var seconds: Double

    public init(stage: String, page: String, outcome: Outcome = .running, error: String? = nil,
                started: Date = Date(), seconds: Double = 0) {
        self.stage = stage
        self.page = page
        self.outcome = outcome
        self.error = error
        self.started = started
        self.seconds = seconds
    }

    /// `timeout @page library 8.0s · HTTP 500`: what the widget's diagnostic line reads.
    public var line: String {
        let label = outcome == .running ? "killed" : outcome.rawValue
        let tail = error.map { " · \($0)" } ?? ""
        return "\(label) @\(stage) \(page) \(String(format: "%.1f", seconds))s\(tail)"
    }

    /// True when this run never finished while loading `page`'s data: the
    /// next reload shows a retry line for that page instead of loading it again.
    public func died(loading page: String) -> Bool {
        outcome == .running && stage == "page" && self.page == page
    }

    /// The diagnostic line to show: this run's failure, else a previous run
    /// that was killed mid-way; nothing after a clean run.
    public static func diagnostic(current: WidgetRunLog, previous: WidgetRunLog?) -> String? {
        switch current.outcome {
        case .failed, .timedOut: return current.line
        case .ok, .running: return previous?.outcome == .running ? previous?.line : nil
        }
    }

    /// A short, locale-free name for an error: `timeout 4s`, `HTTP 502`,
    /// `net -1001`, `decode: missing editions`.
    public static func describe(_ error: Error) -> String {
        switch error {
        case let timeout as WidgetTimedOut: return "timeout \(Int(timeout.seconds.rounded()))s"
        case let api as APIError: return describe(api)
        case let url as URLError: return "net \(url.code.rawValue)"
        case let decoding as DecodingError: return describe(decoding)
        case let large as WidgetPayloadTooLarge: return "too large \(large.bytes >> 20)MB"
        case is CancellationError: return "cancelled"
        default:
            let ns = error as NSError
            return "\(ns.domain) \(ns.code)"
        }
    }

    private static func describe(_ error: APIError) -> String {
        switch error {
        case .http(let status, _): return "HTTP \(status)"
        case .notSignedIn: return "signed out"
        case .invalidServerURL: return "bad server URL"
        }
    }

    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, _): return "decode: missing \(key.stringValue)"
        case .typeMismatch(_, let context), .valueNotFound(_, let context):
            return "decode: bad \(context.codingPath.last?.stringValue ?? "value")"
        case .dataCorrupted: return "decode: bad JSON"
        @unknown default: return "decode"
        }
    }
}
