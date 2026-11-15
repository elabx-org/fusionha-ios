import XCTest
@testable import FusionhaKit

/// The hologram's room (`TabletopRoom`) against the stage bench's `stage`:
/// a back wall 300 behind the hinge and 330 tall, two side walls at the
/// display's edges, all of it behind the hinge so it is drawn wholly on the
/// standing half.
final class TabletopRoomTests: XCTestCase {
    private let tolerance = 1e-3

    private func phi(_ hinge: Double) -> Double { (hinge - 90) * Double.pi / 180 }

    private func assertVec(_ v: TabletopVec, _ x: Double, _ y: Double, _ z: Double,
                           file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(v.x, x, accuracy: tolerance, file: file, line: line)
        XCTAssertEqual(v.y, y, accuracy: tolerance, file: file, line: line)
        XCTAssertEqual(v.z, z, accuracy: tolerance, file: file, line: line)
    }

    func testLines() {
        XCTAssertEqual(TabletopRoom.backVerticals.count, 13)
        XCTAssertEqual(TabletopRoom.backHorizontals.count, 6)
        XCTAssertEqual(TabletopRoom.sideHorizontals.count, 12)
        XCTAssertEqual(TabletopRoom.sideVerticals.count, 8)
        XCTAssertEqual(TabletopRoom.lines.count, 39)

        let back = TabletopRoom.backVerticals
        assertVec(back[0].from, -334.5, 0, -300)
        assertVec(back[0].to, -334.5, -330, -300)
        assertVec(back[1].from, -278.75, 0, -300)
        assertVec(back[12].to, 334.5, -330, -300)

        let rows = TabletopRoom.backHorizontals
        assertVec(rows[0].from, -334.5, -55, -300)
        assertVec(rows[0].to, 334.5, -55, -300)
        assertVec(rows[5].to, 334.5, -330, -300)

        let side = TabletopRoom.sideHorizontals
        assertVec(side[0].from, -334.5, -55, -300)
        assertVec(side[0].to, -334.5, -55, 0)
        assertVec(side[11].to, 334.5, -330, 0)

        let posts = TabletopRoom.sideVerticals
        XCTAssertEqual(posts.map(\.from.z), [-300, -200, -100, 0, -300, -200, -100, 0])
        assertVec(posts[3].to, -334.5, -330, 0)
        assertVec(posts[7].from, 334.5, 0, 0)
    }

    /// Seen from the seat, every line is on the standing half: at 50° and
    /// 105° the back wall's foot is 244.5 pt up it, its top 488.7 (under the
    /// bar), and the side walls run down to the hinge's ends.
    func testDrawnOnTheStandingHalf() {
        let eye = TabletopProjection.eye(elevation: 50)
        let foot = TabletopProjection.onScreen(TabletopRoom.backVerticals[0].from, phi: phi(105), eye: eye)
        XCTAssertEqual(foot.x, -291.5294, accuracy: tolerance)
        XCTAssertEqual(foot.y, 244.5102, accuracy: tolerance)
        let top = TabletopProjection.onScreen(TabletopRoom.backVerticals[0].to, phi: phi(105), eye: eye)
        XCTAssertEqual(top.y, 488.6992, accuracy: tolerance)
        let corner = TabletopProjection.onScreen(TabletopRoom.sideVerticals[3].from, phi: phi(105), eye: eye)
        XCTAssertEqual(corner.x, -334.5, accuracy: tolerance)
        XCTAssertEqual(corner.y, 0, accuracy: tolerance)
        for seat in stride(from: 26.0, through: 68, by: 1) {
            let eye = TabletopProjection.eye(elevation: seat)
            for degrees in stride(from: 92.0, through: 135, by: 1) {
                for line in TabletopRoom.lines {
                    for v in [line.from, line.to] {
                        XCTAssertGreaterThanOrEqual(TabletopProjection.onScreen(v, phi: phi(degrees), eye: eye).y, -1e-9)
                    }
                }
            }
        }
    }
}
