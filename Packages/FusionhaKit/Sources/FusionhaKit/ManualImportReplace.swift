import Foundation

// Manual Import safety (fusionha 0.4.233, B1/B2): a held row is exempt from
// the replace verdict only on the slot its hold judged (`held_target`); an
// import over a copy that is as good or better asks first ("Replace your
// copy?", the web's `ReplaceConfirm` / `replaceConfirm`); the server refuses
// it otherwise (422 `invalid_rows`), and a stored leave refuses a remove
// (409 `leave_stands`).

/// The slot a held rescue row's hold was judged on (`rows[].held_target`):
/// `[item_id, tier, movie_edition, sorted episode ids]` on the wire. Nil on a
/// row the hold never judged slot by slot (a pack, a retarget, an older scan).
public struct ManualImportHeldTarget: Decodable, Sendable, Hashable {
    public let itemId: Int?
    public let tier: String?
    public let edition: String?
    public let episodeIds: [Int]

    public init(itemId: Int?, tier: String?, edition: String?, episodeIds: [Int]) {
        self.itemId = itemId
        self.tier = tier
        self.edition = edition
        self.episodeIds = episodeIds
    }

    public init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        var item: Int?, tier: String?, edition: String?, episodes: [Int]?
        if !c.isAtEnd { item = try c.decodeIfPresent(Int.self) }
        if !c.isAtEnd { tier = try c.decodeIfPresent(String.self) }
        if !c.isAtEnd { edition = try c.decodeIfPresent(String.self) }
        if !c.isAtEnd { episodes = try c.decodeIfPresent([Int].self) }
        self.init(itemId: item, tier: tier, edition: edition, episodeIds: episodes ?? [])
    }
}

extension ManualImportDecide {
    /// The row still targets the slot its hold judged (the server's `held_exempt`).
    public static func onHeldSlot(_ row: ManualImportRow) -> Bool {
        guard let held = row.heldTarget else { return false }
        return held.itemId == row.match.itemId && held.tier == row.target.tier
            && held.edition == row.target.edition && held.episodeIds == row.target.coveredEpisodeIds.sorted()
    }

    /// The one-line compare an import asks about when it would replace a copy
    /// that is as good or better (no verdict counts as not an upgrade). Nil when
    /// the slot is empty, the file is an upgrade, or Import anyway is chosen.
    /// "Replaces your WEBDL-1080p FLUX copy, which is as good as this file · CF 4875 → 4825".
    public static func replaceConfirm(_ row: ManualImportRow) -> String? {
        guard let ef = row.existingFile, row.replaceChoice != "import", ef.verdict?.upgrade != true else { return nil }
        let copy = "your \(DetailText.quality(ef.quality))\(ef.releaseGroup.map { " \($0)" } ?? "") copy"
        let same = ef.verdict?.code == "equal_quality_no_cf_gain"
        let cf = ef.cfScore.flatMap { cur in row.incomingCf?.score.map { " · CF \(cur) → \($0)" } } ?? ""
        return "Replaces \(copy), which is \(same ? "as good as" : "better than") this file\(cf)"
    }

    /// The toast after a Re-match, which only re-targets the row (B1).
    public static func rematchedNotice(_ row: ManualImportRow) -> String {
        replaceConfirm(row) != nil
            ? "Re-matched. That episode already has a copy as good or better: choose Import this file or Keep current."
            : "Re-matched. Decide this file on its new episode."
    }
}

/// A row the commit preflight refused because it would replace an equal or
/// better copy without Import anyway (`review_gate.review_block`).
public struct ManualImportReplaceRefusal: Equatable, Sendable {
    public let rowId: Int
    public let reason: String
}

/// A remove refused because a leave chosen on another file stands (409 `leave_stands`).
public struct ManualImportLeaveStands: Equatable, Sendable {
    public let downloadId: Int?
    public let rowId: Int?
    /// The server's sentence.
    public let detail: String
}

extension APIError {
    /// The refused rows that only need "Replace your copy?" (422 `invalid_rows`
    /// whose reason ends "choose Keep current file or Import anyway").
    public var replaceRefusals: [ManualImportReplaceRefusal] {
        guard case .http(422, let body) = self,
              let object = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any],
              let detail = object["detail"] as? [String: Any],
              let rows = detail["invalid_rows"] as? [[String: Any]] else { return [] }
        return rows.compactMap { r in
            guard let id = r["row_id"] as? Int, let reason = r["reason"] as? String,
                  reason.hasSuffix("choose Keep current file or Import anyway") else { return nil }
            return ManualImportReplaceRefusal(rowId: id, reason: reason)
        }
    }

    /// A 409 `leave_stands` with the server's sentence, else nil.
    public var leaveStands: ManualImportLeaveStands? {
        guard case .http(409, let body) = self,
              let object = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any],
              let detail = object["detail"] as? [String: Any],
              detail["code"] as? String == "leave_stands" else { return nil }
        return ManualImportLeaveStands(downloadId: detail["download_id"] as? Int, rowId: detail["row_id"] as? Int,
                                       detail: detail["detail"] as? String ?? ManualImportCopy.leaveStands)
    }
}
