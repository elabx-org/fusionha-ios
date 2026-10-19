import XCTest

/// fusionha's shared palettes (`design/palettes.json`, pinned from v0.4.221 at
/// `Shared/palettes.json`) against the app's `PaletteTokens` in
/// `Shared/AppPalette.swift`. The app target can't be imported here, so the
/// Swift literals are read from source: every palette in the JSON must exist
/// in Swift with the same hex, opacity and flags (a status colour left out
/// of a Swift palette takes the struct's default). `onAccent` is computed by
/// contrast on both sides and is never stored.
final class SharedPalettesTests: XCTestCase {
    private var repo: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
    }

    private func load() throws -> (json: [String: [String: Any]], order: [String], swift: String) {
        let data = try Data(contentsOf: repo.appendingPathComponent("Shared/palettes.json"))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let palettes = try XCTUnwrap(root["palettes"] as? [String: [String: Any]])
        let order = (root["dark"] as? [String] ?? []) + (root["light"] as? [String] ?? [])
        let swift = try String(contentsOf: repo.appendingPathComponent("Shared/AppPalette.swift"), encoding: .utf8)
        return (palettes, order, swift)
    }

    private func matches(_ pattern: String, in text: String) -> [[String]] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { m in
            (0..<m.numberOfRanges).map { m.range(at: $0).location == NSNotFound ? "" : ns.substring(with: m.range(at: $0)) }
        }
    }

    private func hex(_ s: String) -> UInt32? {
        let t = s.hasPrefix("#") ? String(s.dropFirst()) : s.hasPrefix("0x") ? String(s.dropFirst(2)) : s
        return UInt32(t, radix: 16)
    }

    func testEveryListedPaletteIsDefined() throws {
        let (json, order, _) = try load()
        XCTAssertEqual(Set(order), Set(json.keys))
        XCTAssertTrue(order.contains("daylight") && order.contains("monochrome"))
    }

    func testSwiftTokensMatchTheSharedJSON() throws {
        let (json, _, swift) = try load()
        var defaults: [String: String] = [:]
        for m in matches(#"var (\w+): UInt32 = (0x[0-9A-Fa-f]+)"#, in: swift) { defaults[m[1]] = m[2] }
        for (name, palette) in json {
            let block = try XCTUnwrap(matches("static let \(name) = PaletteTokens\\((.*?)\\)\\n", in: swift).first?[1],
                                      "\(name) is missing from AppPalette.swift")
            var fields: [String: String] = [:]
            for m in matches(#"(\w+): (0x[0-9A-Fa-f]+|true|false|[0-9]+\.[0-9]+)"#, in: block) { fields[m[1]] = m[2] }
            XCTAssertNil(fields["onAccent"], "\(name): onAccent is computed, never stored")
            for (key, value) in palette where key != "name" && key != "blurb" {
                switch value {
                case let s as String where s.hasPrefix("#"):
                    let swiftValue = fields[key] ?? defaults[key]
                    XCTAssertEqual(swiftValue.flatMap(hex), hex(s), "\(name).\(key)")
                case let flag as Bool:
                    XCTAssertEqual(fields[key] ?? "false", flag ? "true" : "false", "\(name).\(key)")
                case let n as NSNumber:
                    XCTAssertEqual(fields[key].flatMap(Double.init) ?? -1, n.doubleValue, accuracy: 1e-9, "\(name).\(key)")
                default:
                    XCTFail("\(name).\(key): unexpected value \(value)")
                }
            }
        }
    }
}
