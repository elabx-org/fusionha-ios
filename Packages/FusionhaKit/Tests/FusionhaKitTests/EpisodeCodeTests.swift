import XCTest
@testable import FusionhaKit

final class EpisodeCodeTests: XCTestCase {
    func testCodes() {
        XCTAssertEqual(EpisodeCode.episode(season: 2, episode: 3), "S02·E03")
        XCTAssertEqual(EpisodeCode.episode(season: 2, episode: 3, separator: ""), "S02E03")
        XCTAssertEqual(EpisodeCode.episode(season: 0, episode: 1), "S00·E01")
        XCTAssertEqual(EpisodeCode.episode(season: 12, episode: 100), "S12·E100")
        XCTAssertEqual(EpisodeCode.range(season: 1, first: 1, last: 6), "S01·E01–E06")
        XCTAssertEqual(EpisodeCode.range(season: 1, first: 4, last: 4), "S01·E04")
        XCTAssertEqual(EpisodeCode.absolute(5), "#05")
        XCTAssertEqual(EpisodeCode.absolute(1071), "#1071")
        XCTAssertEqual(EpisodeCode.season(0), "S00")
    }
}
