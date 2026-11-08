import XCTest
@testable import FusionhaKit

/// Drag to tick a run of Manual Import rows, and the j/k cursor.
final class MIRowSweepTests: XCTestCase {
    private let ids = [10, 11, 12, 13]
    private let spans: [Int: ClosedRange<Double>] = [10: 0...40, 11: 41...80, 12: 81...120, 13: 121...160]

    func testRowAtY() {
        XCTAssertEqual(MIRowSweep.row(at: 50, ids: ids, spans: spans), 11)
        XCTAssertEqual(MIRowSweep.row(at: -30, ids: ids, spans: spans), 10)
        XCTAssertEqual(MIRowSweep.row(at: 400, ids: ids, spans: spans), 13)
        XCTAssertEqual(MIRowSweep.row(at: 80.6, ids: ids, spans: spans), 12)
        XCTAssertNil(MIRowSweep.row(at: 10, ids: ids, spans: [:]))
    }

    func testRunEitherWay() {
        XCTAssertEqual(MIRowSweep.run(from: 11, to: 13, ids: ids), [11, 12, 13])
        XCTAssertEqual(MIRowSweep.run(from: 13, to: 11, ids: ids), [11, 12, 13])
        XCTAssertEqual(MIRowSweep.run(from: 12, to: 12, ids: ids), [12])
        XCTAssertEqual(MIRowSweep.run(from: 99, to: 12, ids: ids), [])
    }

    func testSelectionTicksOrUnticksAndSkipsLocked() {
        let run = [11, 12, 13]
        XCTAssertEqual(MIRowSweep.selection(base: [10], run: run, on: true, locked: [12]), [10, 11, 13])
        XCTAssertEqual(MIRowSweep.selection(base: [10, 11, 12], run: run, on: false), [10])
        // Sweeping back shrinks the run: the base comes back.
        XCTAssertEqual(MIRowSweep.selection(base: [13], run: [11], on: true), [11, 13])
    }

    func testStep() {
        XCTAssertEqual(MIRowSweep.step(nil, by: 1, ids: ids), 10)
        XCTAssertEqual(MIRowSweep.step(nil, by: -1, ids: ids), 13)
        XCTAssertEqual(MIRowSweep.step(11, by: 1, ids: ids), 12)
        XCTAssertEqual(MIRowSweep.step(13, by: 1, ids: ids), 13)
        XCTAssertEqual(MIRowSweep.step(10, by: -1, ids: ids), 10)
        XCTAssertEqual(MIRowSweep.step(99, by: 1, ids: ids), 10)
        XCTAssertNil(MIRowSweep.step(nil, by: 1, ids: []))
    }
}
