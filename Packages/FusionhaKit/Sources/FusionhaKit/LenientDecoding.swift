import Foundation

extension KeyedDecodingContainer {
    /// The value at `key`, or `fallback` when it is missing, `null` or of
    /// another type: a newer or older server never breaks the decode.
    func orDefault<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
    }

    /// The value at `key`, or nil when it is missing, `null` or of another type.
    func lenient<T: Decodable>(_ key: Key) -> T? {
        (try? decodeIfPresent(T.self, forKey: key)) ?? nil
    }
}
