import XCTest
@testable import FusionhaKit

/// The v2 badge state: filled on disk, outline missing, ring downloading,
/// orange "!" held, and the joined-ticket rule.
final class EditionBadgeStateTests: XCTestCase {
    private func rail(_ state: RailState, fraction: String? = nil, attention: Bool = false, deadLink: Bool = false) -> Rail {
        Rail(state: state, progress: 0, fraction: fraction, attention: attention, deadLinkOnly: deadLink)
    }

    func testRailStates() {
        XCTAssertEqual(EditionBadgeState(rail: rail(.owned)), .onDisk)
        XCTAssertEqual(EditionBadgeState(rail: rail(.wanted)), .missing)
        XCTAssertEqual(EditionBadgeState(rail: rail(.upcoming)), .missing)
        XCTAssertEqual(EditionBadgeState(rail: rail(.partial, fraction: "3/5")), .partial(have: 3, of: 5))
    }

    func testPartialWithoutUsableCountReadsOnDisk() {
        XCTAssertEqual(EditionBadgeState(rail: rail(.partial, fraction: nil)), .onDisk)
        XCTAssertEqual(EditionBadgeState(rail: rail(.partial, fraction: "5/5")), .onDisk)
    }

    func testUpgradingReadsAsDownloading() {
        XCTAssertEqual(EditionBadgeState(rail: rail(.upgrading)), .downloading(progress: nil))
        XCTAssertEqual(EditionBadgeState(rail: rail(.downloading), queue: QueueProgress(percent: 40, held: false)),
                       .downloading(progress: 0.4))
    }

    func testAttentionDeadLinkAndHeldImportReadHeld() {
        XCTAssertEqual(EditionBadgeState(rail: rail(.owned, attention: true)), .held)
        XCTAssertEqual(EditionBadgeState(rail: rail(.partial, fraction: "1/4", attention: true, deadLink: true)), .held)
        XCTAssertEqual(EditionBadgeState(rail: rail(.downloading), queue: QueueProgress(percent: 100, held: true)), .held)
    }

    func testWireStatuses() {
        XCTAssertEqual(EditionBadgeState(status: .downloaded), .onDisk)
        XCTAssertEqual(EditionBadgeState(status: .upgrading), .downloading(progress: nil))
        XCTAssertEqual(EditionBadgeState(status: .downloading), .downloading(progress: nil))
        XCTAssertEqual(EditionBadgeState(status: .deadlink), .held)
        XCTAssertEqual(EditionBadgeState(status: .stuck), .held)
        XCTAssertEqual(EditionBadgeState(status: .missing), .missing)
        XCTAssertEqual(EditionBadgeState(status: .unaired), .missing)
        XCTAssertEqual(EditionBadgeState(status: .other("new")), .missing)
    }

    func testAppearance() {
        XCTAssertTrue(EditionBadgeState.onDisk.isFilled)
        XCTAssertTrue(EditionBadgeState.partial(have: 1, of: 2).isFilled)
        XCTAssertFalse(EditionBadgeState.missing.isFilled)
        XCTAssertFalse(EditionBadgeState.downloading(progress: 0.5).isFilled)
        XCTAssertTrue(EditionBadgeState.downloading(progress: nil).showsRing)
        XCTAssertFalse(EditionBadgeState.held.showsRing)
        XCTAssertEqual(EditionBadgeState.partial(have: 6, of: 8).count, "6/8")
        XCTAssertNil(EditionBadgeState.onDisk.count)
    }

    func testJoinsOnlyWhenBothSayTheSameAndCarryNothing() {
        XCTAssertTrue(EditionBadgeState.joins(.onDisk, .onDisk))
        XCTAssertTrue(EditionBadgeState.joins(.missing, .missing))
        XCTAssertFalse(EditionBadgeState.joins(.held, .held))
        XCTAssertFalse(EditionBadgeState.joins(.downloading(progress: 0.2), .downloading(progress: 0.2)))
        XCTAssertFalse(EditionBadgeState.joins(.partial(have: 1, of: 2), .partial(have: 1, of: 2)))
        XCTAssertFalse(EditionBadgeState.joins(.onDisk, .missing))
    }

    func testSpeech() {
        XCTAssertEqual(EditionBadgeSpeech.label(hd: .onDisk, uhd: .downloading(progress: 0.4)), "HD on disk, 4K downloading 40%")
        XCTAssertEqual(EditionBadgeSpeech.label(hd: .onDisk, uhd: .onDisk), "HD and 4K on disk")
        XCTAssertEqual(EditionBadgeSpeech.label(hd: .missing, uhd: .missing), "HD and 4K missing")
        XCTAssertEqual(EditionBadgeSpeech.label(hd: .partial(have: 3, of: 5), uhd: .held), "HD 3 of 5 on disk, 4K held")
        XCTAssertEqual(EditionBadgeSpeech.label(hd: nil, uhd: .downloading(progress: nil)), "4K downloading")
        XCTAssertEqual(EditionBadgeSpeech.label(hd: .onDisk, uhd: nil), "HD on disk")
    }

    func testBadgeLetters() {
        XCTAssertEqual(QualityTier.hd.badgeLetters, "HD")
        XCTAssertEqual(QualityTier.uhd.badgeLetters, "4K")
    }
}
