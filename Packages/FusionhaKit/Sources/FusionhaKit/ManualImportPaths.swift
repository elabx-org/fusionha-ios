import Foundation

/// The scanned root as the phone and Duo show it (web `SourceLine`): "parent / last",
/// the last folder shortened in the middle when long.
public enum ManualImportPaths {
    public struct SourceLine: Equatable, Sendable {
        /// The folder above the scanned one; empty at the root ("/downloads").
        public let parent: String
        public let last: String
    }

    public static func sourceLine(_ path: String) -> SourceLine {
        var trimmed = Substring(path)
        while trimmed.hasSuffix("/") { trimmed = trimmed.dropLast() }
        var segments = trimmed.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        let last = segments.popLast() ?? ""
        let parent = segments.popLast() ?? ""
        return SourceLine(parent: parent, last: middle(last))
    }

    /// "Mad.Men.S04E02.…HDR.H.265-WADU": first 15 and last 14 characters past 34.
    static func middle(_ s: String) -> String {
        s.count > 34 ? "\(s.prefix(15))…\(s.suffix(14))" : s
    }
}
