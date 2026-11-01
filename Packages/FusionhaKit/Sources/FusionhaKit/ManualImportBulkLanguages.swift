import Foundation

public extension ManualImportBatch {
    /// The language set every row shares, ignoring order, to seed bulk "Set
    /// languages" (the web's `sharedLangs` in `BulkSheet.tsx`). Nil when the
    /// rows differ ("Mixed"), so the page starts empty; empty with no rows.
    static func sharedLanguages(_ rows: [ManualImportRow]) -> [String]? {
        guard let first = rows.first else { return [] }
        let key = { (r: ManualImportRow) in (r.languages ?? []).sorted() }
        let firstKey = key(first)
        return rows.allSatisfy { key($0) == firstKey } ? (first.languages ?? []) : nil
    }
}
