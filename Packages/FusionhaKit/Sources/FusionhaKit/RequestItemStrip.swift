import Foundation

// A5: everyone who asked for a title, on its detail page (web
// `RequestsStrip` + `labels.ts`), and "Message all" (`POST /requests/broadcast`).

/// One row of `GET /library/{id}/requests`: the request and who joined it.
public struct ItemRequestRow: Decodable, Identifiable {
    public let request: MediaRequest
    public let joiners: [RequestPerson]?
    public var id: Int { request.id }
}

struct BroadcastResult: Decodable { let requestIds: [Int] }

public enum RequestItemStrip {
    /// Live on the server: the set a broadcast reaches.
    public static func isOpen(_ r: MediaRequest) -> Bool {
        ["pending", "approved", "deferred", "waiting"].contains(r.status)
    }

    /// Distinct people who asked, withdrawn requests excluded.
    public static func askerCount(_ requests: [MediaRequest]) -> Int {
        Set(requests.filter { $0.status != "withdrawn" }.map { $0.userId ?? -$0.id }).count
    }

    /// The strip header's count line, truthful for any status mix.
    public static func summary(_ requests: [MediaRequest]) -> String {
        let open = askerCount(requests.filter(isOpen))
        let fulfilled = requests.filter { $0.status == "fulfilled" }.count
        let notice = "everyone is notified when it’s available"
        if open > 0 {
            let who = "\(open) \(open == 1 ? "person" : "people")"
            return fulfilled > 0 ? "\(who) · \(fulfilled) fulfilled · \(notice)" : "\(who) · \(notice)"
        }
        if fulfilled > 0 {
            return fulfilled == requests.count ? "\(fulfilled) request\(fulfilled == 1 ? "" : "s") · fulfilled" : "\(fulfilled) fulfilled"
        }
        return "No open requests"
    }

    /// "Approved by Elmer" / "Auto-approved · Rule" / "Watching".
    public static func approvedText(_ by: RequestApprovedBy?) -> String? {
        guard let by else { return nil }
        switch by.kind {
        case "auto": return by.rule.map { "Auto-approved · \($0)" } ?? "Auto-approved"
        case "watch": return "Watching"
        default: return by.displayName.map { "Approved by \($0)" }
        }
    }
}

extension APIClient {
    /// Everyone who asked for this title (managers and approvers; `[]` for others).
    public func itemRequests(itemId: Int) async throws -> [ItemRequestRow] {
        try await get("/api/v1/library/\(itemId)/requests")
    }

    /// One line posted to every open request thread for the title; returns how many threads.
    public func broadcastRequests(mediaItemId: Int, body: String) async throws -> Int {
        let res: BroadcastResult = try await sendJSON("POST", "/api/v1/requests/broadcast",
                                                      ["media_item_id": .int(mediaItemId), "body": .string(body)])
        return res.requestIds.count
    }
}
