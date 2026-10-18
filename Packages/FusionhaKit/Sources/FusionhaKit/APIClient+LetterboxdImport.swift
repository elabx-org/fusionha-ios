import Foundation

/// The Letterboxd one-time import (upload → paced matching → commit) and the
/// Discover "From your Letterboxd" rail. Web: `lib/api/letterboxd-csv.ts`,
/// `lib/api/suggestions.ts`.
extension APIClient {
    /// A `watchlist.csv` up to 1 MiB, or the export ZIP up to 10 MiB (the web's
    /// client check; the server re-checks).
    public static let letterboxdCsvMaxBytes = 1_048_576
    public static let letterboxdZipMaxBytes = 10_485_760

    /// Whether a file is over the import's size limit before it is sent.
    public static func letterboxdFileTooLarge(name: String, size: Int) -> Bool {
        let zip = name.lowercased().hasSuffix(".zip")
        return size > (zip ? letterboxdZipMaxBytes : letterboxdCsvMaxBytes)
    }

    /// `POST /me/letterboxd/watchlist-csv/preview` as multipart `file` (202).
    /// Once a minute, counted before the body is read (429 `retry_after`);
    /// 413 `too_large`, 422 `too_many_rows` / `invalid_file`.
    public func uploadLetterboxdExport(_ data: Data, filename: String) async throws -> CsvPreviewStarted {
        let form = MultipartForm()
        let zip = filename.lowercased().hasSuffix(".zip")
        var req = request(method: "POST", path: "/api/v1/me/letterboxd/watchlist-csv/preview", query: [])
        req.httpBody = form.body(field: "file", filename: filename,
                                 mimeType: zip ? "application/zip" : "text/csv", data: data)
        req.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60
        return try await perform(req)
    }

    /// Polled every second while `MATCHING`; expires after 24 hours.
    public func letterboxdImportPreview(token: String) async throws -> CsvPreviewRead {
        try await get("/api/v1/me/letterboxd/watchlist-csv/preview/\(token)")
    }

    /// Requests up to `requestNow` (10, 25, 50 or 100) now and wishlists the
    /// rest. 409 `not_ready`, `already_committed`, `expired`.
    public func commitLetterboxdImport(token: String, requestNow: Int,
                                       includeLowConfidence: [String]) async throws -> CsvCommitResult {
        let body: SettingsJSON = [
            "preview_token": .string(token),
            "request_now": .int(requestNow),
            "include_low_confidence": .array(includeLowConfidence.map(SettingsJSON.string)),
        ]
        return try await sendJSON("POST", "/api/v1/me/letterboxd/watchlist-csv/commit", body)
    }

    /// Titles from the caller's Letterboxd sources that aren't in the library
    /// or requested yet; `sourceId` narrows to one source.
    public func suggestions(sourceId: Int? = nil) async throws -> SuggestionsRead {
        var query: [URLQueryItem] = []
        if let sourceId { query.append(URLQueryItem(name: "source_id", value: "\(sourceId)")) }
        return try await get("/api/v1/me/suggestions", query: query)
    }
}
