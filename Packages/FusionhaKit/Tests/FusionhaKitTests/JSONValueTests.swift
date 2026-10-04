import Foundation
import XCTest
@testable import FusionhaKit

final class JSONValueTests: XCTestCase {
    func testParsesSettingsKeepingSnakeCaseKeys() throws {
        let data = Data(#"{"animations_enabled": false, "rss_interval_seconds": 900, "ui_theme": "aurora", "x": null, "p": {"title": ["tmdb"]}}"#.utf8)
        let value = JSONValue(any: try JSONSerialization.jsonObject(with: data))
        XCTAssertEqual(value["animations_enabled"]?.bool, false)
        XCTAssertEqual(value["rss_interval_seconds"]?.int, 900)
        XCTAssertNil(value["rss_interval_seconds"]?.bool)
        XCTAssertEqual(value["ui_theme"]?.string, "aurora")
        XCTAssertEqual(value["x"], .null)
        XCTAssertEqual(value["p"]?["title"]?.array?.first?.string, "tmdb")
    }

    func testWritesIntegersAsIntegers() throws {
        let body: JSONValue = .object(["rss_interval_seconds": .number(1800), "ratio": .number(0.5), "on": .bool(true)])
        let text = String(decoding: try JSONSerialization.data(withJSONObject: body.any, options: [.sortedKeys]), as: UTF8.self)
        XCTAssertEqual(text, #"{"on":true,"ratio":0.5,"rss_interval_seconds":1800}"#)
    }
}
