import Foundation

/// A file name the server supplied (a backup id, a recovery key's filename),
/// made safe to write on this phone: only `[A-Za-z0-9._-]`, never `..` or a
/// path, and always inside the folder it was meant for.
public enum SafeFileName {
    private static let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")

    /// The name with anything outside the safe set replaced by `_`. A name that
    /// is empty, only dots, or contains `..` gives `fallback` instead.
    public static func sanitize(_ raw: String, fallback: String) -> String {
        let cleaned = String(raw.map { allowed.contains($0) ? $0 : "_" })
        if cleaned.isEmpty || cleaned.contains("..") || cleaned.allSatisfy({ $0 == "." }) { return fallback }
        return cleaned
    }

    /// `folder/<sanitized name>`, or nil if the result would land anywhere
    /// but directly inside `folder`.
    public static func file(named raw: String, in folder: URL, fallback: String) -> URL? {
        let name = sanitize(raw, fallback: fallback)
        guard name == sanitize(name, fallback: ""), !name.isEmpty else { return nil }
        let base = folder.standardizedFileURL
        let file = base.appendingPathComponent(name, isDirectory: false).standardizedFileURL
        guard file.deletingLastPathComponent().path == base.path else { return nil }
        return file
    }
}
