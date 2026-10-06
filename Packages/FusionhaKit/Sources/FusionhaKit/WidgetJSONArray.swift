import Foundation

/// Walks a top-level JSON array and hands over one element's bytes at a time,
/// so a widget can tally a large list (the whole library) while only one
/// element is ever decoded. Strings and escapes are respected; the elements
/// themselves are not validated (their decoder does that).
public enum WidgetJSONArray {
    public struct Malformed: Error, Equatable {}

    public static func forEachElement(in data: Data, _ body: (Data) throws -> Void) throws {
        try data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            var scanner = Scanner(bytes: raw)
            try scanner.run(body)
        }
    }

    private struct Scanner {
        let bytes: UnsafeRawBufferPointer
        var index = 0
        var depth = 0
        var inString = false
        var escaped = false
        var start: Int?

        init(bytes: UnsafeRawBufferPointer) {
            self.bytes = bytes
        }

        mutating func run(_ body: (Data) throws -> Void) throws {
            while index < bytes.count, Self.isSpace(bytes[index]) { index += 1 }
            guard index < bytes.count, bytes[index] == UInt8(ascii: "[") else { throw Malformed() }
            index += 1
            while index < bytes.count {
                if try step(bytes[index], body) { return }
                index += 1
            }
            throw Malformed()
        }

        /// Consumes one byte; true at the array's closing bracket.
        private mutating func step(_ byte: UInt8, _ body: (Data) throws -> Void) throws -> Bool {
            if inString {
                if escaped { escaped = false } else if byte == UInt8(ascii: "\\") { escaped = true } else if byte == UInt8(ascii: "\"") { inString = false }
                return false
            }
            switch byte {
            case UInt8(ascii: "\""):
                inString = true
                if start == nil { start = index }
            case UInt8(ascii: "{"), UInt8(ascii: "["):
                if start == nil { start = index }
                depth += 1
            case UInt8(ascii: "}"), UInt8(ascii: "]"):
                if depth == 0 {
                    try emit(body)
                    return true
                }
                depth -= 1
            case UInt8(ascii: ","):
                if depth == 0 { try emit(body) }
            default:
                if start == nil, !Self.isSpace(byte) { start = index }
            }
            return false
        }

        /// The element from `start` up to here, trailing whitespace trimmed.
        private mutating func emit(_ body: (Data) throws -> Void) throws {
            guard let first = start else { return }
            var end = index
            while end > first, Self.isSpace(bytes[end - 1]) { end -= 1 }
            start = nil
            try body(Data(UnsafeRawBufferPointer(rebasing: bytes[first..<end])))
        }

        private static func isSpace(_ byte: UInt8) -> Bool {
            byte == 0x20 || byte == 0x0A || byte == 0x0D || byte == 0x09
        }
    }
}
