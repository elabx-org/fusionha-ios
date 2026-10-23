import XCTest
@testable import FusionhaKit

final class LibraryShelfTests: XCTestCase {
    private func item(_ json: String) throws -> MediaItem {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(MediaItem.self, from: Data(json.utf8))
    }

    private func dated(_ id: Int, _ added: String?) throws -> MediaItem {
        let field = added.map { #", "added_at": "\#($0)""# } ?? ""
        return try item(#"{"id": \#(id), "title": "T\#(id)", "kind": "movie"\#(field), "editions": []}"#)
    }

    private func parse(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: s)
    }

    func testChipsCarryTierStatusAndMovingLabel() throws {
        let series = try item(#"""
            {"id": 1, "title": "A", "kind": "series", "editions": [
              {"id": 1, "tier": "HD-1080p", "monitored": true, "status": "wanted", "have": 3, "total": 5},
              {"id": 2, "tier": "UHD-2160p", "monitored": true, "status": "done", "have": 5, "total": 5}]}
            """#)
        let chips = EditionChipLabel.chips(for: series)
        XCTAssertEqual(chips, [EditionChipLabel(tier: .hd, tone: .wanted, text: "3/5"),
                               EditionChipLabel(tier: .uhd, tone: .done, text: nil)])

        let movie = try item(#"""
            {"id": 2, "title": "Dune", "kind": "movie", "editions": [
              {"id": 3, "tier": "HD-1080p", "monitored": true, "status": "done", "have": 1, "total": 1},
              {"id": 4, "tier": "UHD-2160p", "monitored": true, "status": "grabbing", "have": 0, "total": 1}]}
            """#)
        let live = EditionChipLabel.chips(for: movie) { $0.tier == .uhd ? QueueProgress(percent: 30, held: false) : nil }
        XCTAssertEqual(live[1], EditionChipLabel(tier: .uhd, tone: .grabbing, text: "30%"))
        // No queue row yet: the arrow, never a made-up percent.
        XCTAssertEqual(EditionChipLabel.chips(for: movie)[1].text, "↓")
        // Transferred but still importing: ↓, never "100%" on a version that isn't done.
        XCTAssertEqual(EditionChipLabel.chips(for: movie) { _ in QueueProgress(percent: 100, held: false) }[1].text, "↓")
        // A held import: "!".
        XCTAssertEqual(EditionChipLabel.chips(for: movie) { _ in QueueProgress(percent: 100, held: true) }[1].text, "!")
    }

    func testAttentionAndUpgradeChips() throws {
        let flagged = try item(#"""
            {"id": 3, "title": "B", "kind": "movie", "editions": [
              {"id": 5, "tier": "HD-1080p", "monitored": true, "status": "done", "have": 1, "total": 1,
               "attention": true, "dead_link_count": 1, "unresolved_file_count": 1},
              {"id": 6, "tier": "UHD-2160p", "monitored": true, "status": "upgrading", "have": 1, "total": 1}]}
            """#)
        let chips = EditionChipLabel.chips(for: flagged)
        XCTAssertEqual(chips[0].tone, .deadLink)
        XCTAssertEqual(chips[1], EditionChipLabel(tier: .uhd, tone: .upgrading, text: "↑"))
    }

    func testRecentShelfNewestFirstAndSkipsUndated() throws {
        let items = [try dated(1, "2026-09-01"), try dated(2, nil), try dated(3, "2026-10-02"), try dated(4, "2026-09-20")]
        XCTAssertEqual(RecentShelf.pick(items, parse: parse).map(\.id), [3, 4, 1])
        XCTAssertEqual(RecentShelf.pick(items, parse: parse, limit: 2).map(\.id), [3, 4])
        // A filter that leaves nothing empties (and so hides) the shelf.
        XCTAssertTrue(RecentShelf.pick([], parse: parse).isEmpty)
    }

    func testAddedLine() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = parse("2026-10-23")!.addingTimeInterval(15 * 3600)
        func line(_ day: String) -> String? {
            RecentShelf.addedLine(parse(day), now: now, calendar: cal) { _ in "Oct 1" }
        }
        XCTAssertEqual(line("2026-10-23"), "Added today")
        XCTAssertEqual(line("2026-10-22"), "Added yesterday")
        XCTAssertEqual(line("2026-10-20"), "Added 3 days ago")
        XCTAssertEqual(line("2026-10-01"), "Added Oct 1")
        XCTAssertNil(RecentShelf.addedLine(nil, now: now) { _ in "" })
    }

    func testAmbientWashIsNearWhiteOnLightGroundsAndTheWebsOnDark() {
        let light = AmbientWash.stops(light: true)
        XCTAssertGreaterThanOrEqual(light.map(\.opacity).min() ?? 0, 0.94)
        XCTAssertEqual(light.last?.opacity, 1)
        XCTAssertEqual(AmbientWash.stops(light: false).map(\.opacity), [0.78, 0.62, 0.5])
    }

    func testKindMixShares() {
        XCTAssertEqual(KindMix.shares([5, 4, 5]).map { ($0 * 14).rounded() }, [5, 4, 5])
        XCTAssertEqual(KindMix.shares([0, 0, 0]), [1.0 / 3, 1.0 / 3, 1.0 / 3])
    }
}
