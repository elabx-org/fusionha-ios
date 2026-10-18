import Foundation

// The `created` thread line of an automatic or re-requested row, and the
// auto-approved strip's phrase (web `thread-format.ts` `createdLine`,
// `source-words.ts` `letterboxdCreatedLine` / `stripPhrase`, fusionha 0.4.209
// and 0.4.213). List names and owners come from the request's
// privacy-filtered `source`, never from the thread data.

extension RequestThreadFormat {
    static let automaticTail = ", so fusionha requested it automatically."

    static func createdLine(_ e: RequestThreadEvent, who: String?, label: String?, owner: String?) -> String {
        let name = who ?? "Someone"
        if e.data?.again == true { return e.isMine ? "Requested again by you." : "\(name) requested it again." }
        let your = e.isMine ? "your" : "\(name)’s"
        switch e.data?.source {
        case "PLEX_WATCHLIST":
            return "Added to \(your) Plex watchlist\(automaticTail)"
        case "PLEX_LIST":
            if let label { return "Added to \(your) Plex list “\(label)”\(automaticTail)" }
            return "Added to \(e.isMine ? "one of your Plex lists" : "a Plex list of \(name)’s")\(automaticTail)"
        case let kind?:
            if let lb = letterboxdCreatedLine(kind, your: your, label: label, owner: owner) { return lb }
        case nil:
            break
        }
        return "\(name) requested \(names(e.data))".trimmed
    }

    static func letterboxdCreatedLine(_ kind: String, your: String, label: String?, owner: String?) -> String? {
        switch kind {
        case "LETTERBOXD_RSS":
            return "Logged in \(your) Letterboxd diary\(automaticTail)"
        case "LETTERBOXD_CSV":
            return "Imported from \(your) Letterboxd export\(automaticTail)"
        case "LETTERBOXD_WATCHLIST":
            if let owner { return "Added to @\(owner)’s public Letterboxd watchlist\(automaticTail)" }
            return "Added to \(your) Letterboxd watchlist\(automaticTail)"
        case "LETTERBOXD_LIST":
            guard let label else { return "Found on a Letterboxd list\(automaticTail)" }
            return "Found on the Letterboxd list “\(label)”\(owner.map { " by @\($0)" } ?? "")\(automaticTail)"
        default:
            return nil
        }
    }
}

extension RequestSourceWords {
    /// The auto-approved strip's phrase, or nil for a manual row.
    public static func stripPhrase(_ s: RequestSource?) -> String? {
        guard let s else { return nil }
        switch s.kind {
        case "PLEX_LIST": return "From the Plex list" + (s.label.map { " · \($0)" } ?? "")
        case "PLEX_WATCHLIST": return "From the Plex watchlist"
        case "LETTERBOXD_RSS": return "From a Letterboxd diary"
        case "LETTERBOXD_LIST": return "From the Letterboxd list" + (s.label.map { " · \($0)" } ?? "")
        case "LETTERBOXD_WATCHLIST", "LETTERBOXD_CSV": return "From a Letterboxd watchlist"
        default: return nil
        }
    }
}
