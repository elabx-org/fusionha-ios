import Foundation

// Manual Import's loading, error and empty sentences, worded as the web's
// `routes/manual-import/{ScanStates,ScanBody,ItemMatchDialog}.tsx` word them.
extension ManualImportCopy {
    /// Opening held downloads (web `rescue-loading`).
    public static func rescueLoading(count: Int) -> String {
        count > 1
            ? "Opening \(count) held downloads for a manual (force) import…"
            : "Opening the held download for a manual (force) import…"
    }

    /// Held downloads that could not be opened (web `rescue-error`).
    public static func rescueError(count: Int) -> String {
        count > 1
            ? "These held downloads could not be opened for manual import — some may have already been imported, or their files are no longer on disk."
            : "This held download could not be opened for manual import — it may have already been imported, or its files are no longer on disk."
    }

    /// A folder scan that failed (web `manual-scan-error`).
    public static let scanError = "That folder could not be scanned. Check the path is a directory the server can reach."

    /// A scan with rows, none of which the filter shows (web `manual-filter-empty`).
    public static let filterEmpty = "Nothing matches this filter."

    /// A scan that found no video files at all.
    public static func noVideos(folder: Bool) -> String {
        folder ? "No video files in this folder" : "No video files in this download"
    }

    // The match sheet (web `ItemMatchDialog`).
    public static let libraryLoading = "Loading your library…"
    public static let libraryError = "Your library could not be loaded. Check the backend and try again."
    public static let libraryEmpty = "Your library is empty. Add the title first, then re-scan."

    public static func noLibraryMatch(_ term: String) -> String {
        "No library item matches “\(term.trimmingCharacters(in: .whitespaces))”. Add the title first, then re-scan."
    }

    /// The episode picker's season fetch failed.
    public static let episodesError = "Couldn't load episodes"
}
