import XCTest
@testable import FusionhaKit

final class WidgetRelevanceTests: XCTestCase {
    private let now = CalendarMath.parseUTC("2026-10-04T12:00:00Z")!

    func testDownloadingHighOnlyWhileActive() {
        XCTAssertEqual(WidgetRelevance.downloading(active: 0, stalled: 0), WidgetRelevance.low)
        XCTAssertEqual(WidgetRelevance.downloading(active: 3, stalled: 1), 1)
        XCTAssertEqual(WidgetRelevance.downloading(active: 2, stalled: 2), 0.6)
    }

    func testUpNextRisesTowardAirTime() {
        XCTAssertEqual(WidgetRelevance.upNext(secondsUntilAir: 3 * 86_400), WidgetRelevance.low)
        XCTAssertEqual(WidgetRelevance.upNext(secondsUntilAir: 12 * 3600), 0.2)
        XCTAssertEqual(WidgetRelevance.upNext(secondsUntilAir: 2 * 3600), 0.5)
        XCTAssertEqual(WidgetRelevance.upNext(secondsUntilAir: 30 * 60), 0.8)
        XCTAssertEqual(WidgetRelevance.upNext(secondsUntilAir: 5 * 60), 1)
        XCTAssertEqual(WidgetRelevance.upNext(secondsUntilAir: -60), WidgetRelevance.low)
    }

    func testUpNextStepsStayInsideTheReloadWindow() {
        let air = now.addingTimeInterval(2 * 3600)
        let steps = WidgetRelevance.upNextSteps(airDate: air, now: now, until: now.addingTimeInterval(3 * 3600))
        XCTAssertEqual(steps.map(\.score), [0.5, 0.8, 1])
        XCTAssertEqual(steps.map(\.date), [now, air.addingTimeInterval(-3600), air.addingTimeInterval(-15 * 60)])
        // A reload due sooner keeps only the steps before it.
        let short = WidgetRelevance.upNextSteps(airDate: air, now: now, until: now.addingTimeInterval(30 * 60))
        XCTAssertEqual(short.map(\.score), [0.5])
        XCTAssertEqual(WidgetRelevance.upNextSteps(airDate: nil, now: now, until: now).map(\.score), [WidgetRelevance.low])
    }

    func testRecentFadesOverADay() {
        XCTAssertEqual(WidgetRelevance.recent(secondsSinceImport: 600), 0.7)
        XCTAssertEqual(WidgetRelevance.recent(secondsSinceImport: 3 * 3600), 0.4)
        XCTAssertEqual(WidgetRelevance.recent(secondsSinceImport: 20 * 3600), 0.15)
        XCTAssertEqual(WidgetRelevance.recent(secondsSinceImport: 2 * 86_400), WidgetRelevance.low)
        XCTAssertEqual(WidgetRelevance.recent(secondsSinceImport: nil), WidgetRelevance.low)
        let newest = now.addingTimeInterval(-30 * 60)
        let steps = WidgetRelevance.recentSteps(newest: newest, now: now, until: now.addingTimeInterval(3600))
        XCTAssertEqual(steps.map(\.score), [0.7, 0.4])
        XCTAssertEqual(steps.last?.date, newest.addingTimeInterval(3600))
    }

    func testAttentionWidgets() {
        XCTAssertEqual(WidgetRelevance.indexers(flagged: 0), WidgetRelevance.low)
        XCTAssertEqual(WidgetRelevance.indexers(flagged: 1), 0.4)
        XCTAssertEqual(WidgetRelevance.requests(pending: 2, openIssues: 0), 0.5)
        XCTAssertEqual(WidgetRelevance.requests(pending: 0, openIssues: 1), 0.3)
        XCTAssertEqual(WidgetRelevance.requests(pending: 0, openIssues: 0), WidgetRelevance.low)
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
