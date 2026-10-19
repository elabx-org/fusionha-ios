import Foundation
import FusionhaKit

/// The interactive search's error wording.
enum ReleaseSearchErrorText {
    /// A short, readable cause under the failure banner.
    static func describe(_ error: Error) -> String {
        if let url = error as? URLError {
            return url.code == .timedOut ? "The indexers took too long to answer." : url.localizedDescription
        }
        if case APIError.http(let status, _) = error {
            return detail(error) ?? "The server answered HTTP \(status)."
        }
        if error is DecodingError { return "The server's answer couldn't be read." }
        return error.localizedDescription
    }

    /// The backend's `detail` message on an HTTP error, if it sent one.
    static func detail(_ error: Error) -> String? {
        guard case APIError.http(_, let body) = error,
              let json = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any] else { return nil }
        return json["detail"] as? String
    }
}
