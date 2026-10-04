import Foundation

/// A loosely typed JSON value. Settings panels autosave one key at a time
/// (`PUT /api/v1/settings` with only that key), so they read and write the
/// settings document as a dictionary of these instead of a 150-field struct.
/// Parsed with JSONSerialization, so keys stay exactly as the server sends them
/// (the typed decoder's snake-case conversion would rename them).
public enum JSONValue: Sendable, Equatable, Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(any value: Any?) {
        switch value {
        case nil, is NSNull: self = .null
        case let n as NSNumber:
            if CFGetTypeID(n) == CFBooleanGetTypeID() { self = .bool(n.boolValue) } else { self = .number(n.doubleValue) }
        case let s as String: self = .string(s)
        case let a as [Any]: self = .array(a.map { JSONValue(any: $0) })
        case let d as [String: Any]: self = .object(d.mapValues { JSONValue(any: $0) })
        default: self = .null
        }
    }

    /// The Foundation object JSONSerialization can write.
    public var any: Any {
        switch self {
        case .null: return NSNull()
        case .bool(let b): return b
        case .number(let n): return n.rounded() == n && abs(n) < 1e15 ? Int(n) as Any : n as Any
        case .string(let s): return s
        case .array(let a): return a.map(\.any)
        case .object(let o): return o.mapValues(\.any)
        }
    }

    public var bool: Bool? { if case .bool(let b) = self { return b }; return nil }
    public var double: Double? { if case .number(let n) = self { return n }; return nil }
    public var int: Int? { double.map { Int($0) } }
    public var string: String? { if case .string(let s) = self { return s }; return nil }
    public var array: [JSONValue]? { if case .array(let a) = self { return a }; return nil }
    public var object: [String: JSONValue]? { if case .object(let o) = self { return o }; return nil }
    public var isNull: Bool { self == .null }

    public subscript(key: String) -> JSONValue? { object?[key] }
}

extension JSONValue: ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral, ExpressibleByStringLiteral, ExpressibleByFloatLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(integerLiteral value: Int) { self = .number(Double(value)) }
    public init(floatLiteral value: Double) { self = .number(value) }
    public init(stringLiteral value: String) { self = .string(value) }
}

/// A document from a collection endpoint (`/release-term-filters`,
/// `/config/editions`, `/discover/ignores` …): its id plus every field as JSON.
public struct JSONRecord: Identifiable, Sendable, Equatable, Hashable {
    public var fields: [String: JSONValue]
    public init(_ fields: [String: JSONValue]) { self.fields = fields }
    public var id: Int { fields["id"]?.int ?? 0 }
    public subscript(key: String) -> JSONValue? {
        get { fields[key] }
        set { fields[key] = newValue }
    }
}
