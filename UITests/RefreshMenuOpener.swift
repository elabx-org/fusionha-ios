import XCTest

/// CI helper, not a test of the app: opens the detail page's Refresh split
/// menu (a SwiftUI `Menu`, which no launch flag can open) so
/// scripts/detail_menu_shot.sh can screenshot it. Launches the app on the
/// mock server's movie scrolled to Item actions, taps the caret, prints
/// MENU OPEN and holds the menu open for the screenshot.
final class RefreshMenuOpener: XCTestCase {
    func testOpenRefreshMenu() throws {
        let env = ProcessInfo.processInfo.environment
        let app = XCUIApplication(bundleIdentifier: "org.elabx.fusionha")
        app.launchEnvironment = [
            "FUSIONHA_SCREENSHOT_SERVER": env["MENU_SHOT_SERVER"] ?? "http://127.0.0.1:8765",
            "FUSIONHA_SCREENSHOT_ITEM": env["MENU_SHOT_ITEM"] ?? "1",
            "FUSIONHA_SCREENSHOT_DETAIL_SCROLL": "actions",
        ]
        app.launch()
        let caret = app.buttons["Refresh options"]
        XCTAssertTrue(caret.waitForExistence(timeout: 30), "Refresh options never appeared")
        sleep(3)
        caret.tap()
        let scan = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Refresh & scan'")).firstMatch
        print(scan.waitForExistence(timeout: 10) ? "MENU OPEN" : "MENU OPEN (scan row not found)")
        sleep(25)
    }
}
