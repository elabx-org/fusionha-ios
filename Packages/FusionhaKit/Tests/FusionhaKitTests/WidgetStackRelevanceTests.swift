import XCTest
@testable import FusionhaKit

final class WidgetStackRelevanceTests: XCTestCase {
    private let now = CalendarMath.parseUTC("2026-10-04T12:00:00Z")!

    func testDownloadingHighOnlyWhileActive() {
        XCTAssertEqual(WidgetStackRelevance.downloading(active: 0, stalled: 0), WidgetStackRelevance.low)
        XCTAssertEqual(WidgetStackRelevance.downloading(active: 3, stalled: 1), 1)
        XCTAssertEqual(WidgetStackRelevance.downloading(active: 2, stalled: 2), 0.6)
    }

    func testUpNextRisesTowardAirTime() {
        XCTAssertEqual(WidgetStackRelevance.upNext(secondsUntilAir: 3 * 86_400), WidgetStackRelevance.low)
        XCTAssertEqual(WidgetStackRelevance.upNext(secondsUntilAir: 12 * 3600), 0.2)
        XCTAssertEqual(WidgetStackRelevance.upNext(secondsUntilAir: 2 * 3600), 0.5)
        XCTAssertEqual(WidgetStackRelevance.upNext(secondsUntilAir: 30 * 60), 0.8)
        XCTAssertEqual(WidgetStackRelevance.upNext(secondsUntilAir: 5 * 60), 1)
        XCTAssertEqual(WidgetStackRelevance.upNext(secondsUntilAir: -60), WidgetStackRelevance.low)
    }

    func testUpNextStepsStayInsideTheReloadWindow() {
        let air = now.addingTimeInterval(2 * 3600)
        let steps = WidgetStackRelevance.upNextSteps(airDate: air, now: now, until: now.addingTimeInterval(3 * 3600))
        XCTAssertEqual(steps.map(\.score), [0.5, 0.8, 1])
        XCTAssertEqual(steps.map(\.date), [now, air.addingTimeInterval(-3600), air.addingTimeInterval(-15 * 60)])
        // A reload due sooner keeps only the steps before it.
        let short = WidgetStackRelevance.upNextSteps(airDate: air, now: now, until: now.addingTimeInterval(30 * 60))
        XCTAssertEqual(short.map(\.score), [0.5])
        XCTAssertEqual(WidgetStackRelevance.upNextSteps(airDate: nil, now: now, until: now).map(\.score), [WidgetStackRelevance.low])
    }

    func testRecentFadesOverADay() {
        XCTAssertEqual(WidgetStackRelevance.recent(secondsSinceImport: 600), 0.7)
        XCTAssertEqual(WidgetStackRelevance.recent(secondsSinceImport: 3 * 3600), 0.4)
        XCTAssertEqual(WidgetStackRelevance.recent(secondsSinceImport: 20 * 3600), 0.15)
        XCTAssertEqual(WidgetStackRelevance.recent(secondsSinceImport: 2 * 86_400), WidgetStackRelevance.low)
        XCTAssertEqual(WidgetStackRelevance.recent(secondsSinceImport: nil), WidgetStackRelevance.low)
        let newest = now.addingTimeInterval(-30 * 60)
        let steps = WidgetStackRelevance.recentSteps(newest: newest, now: now, until: now.addingTimeInterval(3600))
        XCTAssertEqual(steps.map(\.score), [0.7, 0.4])
        XCTAssertEqual(steps.last?.date, newest.addingTimeInterval(3600))
    }

    func testAttentionWidgets() {
        XCTAssertEqual(WidgetStackRelevance.indexers(flagged: 0), WidgetStackRelevance.low)
        XCTAssertEqual(WidgetStackRelevance.indexers(flagged: 1), 0.4)
        XCTAssertEqual(WidgetStackRelevance.requests(pending: 2, openIssues: 0), 0.5)
        XCTAssertEqual(WidgetStackRelevance.requests(pending: 0, openIssues: 1), 0.3)
        XCTAssertEqual(WidgetStackRelevance.requests(pending: 0, openIssues: 0), WidgetStackRelevance.low)
    }

    func testStackKindsAreStableAndDistinct() {
        XCTAssertEqual(WidgetStack.allCases.map(\.kind), ["Downloading", "Library", "Indexers", "Requests"])
        let existing: Set<String> = ["Downloads", "UpNext", "RecentlyAdded"]
        XCTAssertTrue(existing.isDisjoint(with: WidgetStack.allCases.map(\.kind)))
        XCTAssertEqual(WidgetStack.requests.page, .requests)
        XCTAssertEqual(WidgetStack.downloading.refreshMinutes(active: true), 15)
        XCTAssertEqual(WidgetStack.downloading.refreshMinutes(active: false), 60)
        XCTAssertEqual(WidgetStack.kind(for: .library), "Library")
        XCTAssertEqual(WidgetStack.kind(for: .upNext), "UpNext")
        XCTAssertEqual(WidgetStack.kind(for: .recent), "RecentlyAdded")
        XCTAssertEqual(WidgetStack.kind(for: .wanted), "Downloads")
    }
}
