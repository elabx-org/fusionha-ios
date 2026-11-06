import XCTest

/// CI helper for scripts/v2_scene_check.sh, not a test of v1: drives fusionha
/// v2 the way the owner does. It launches the app with its DEBUG scene probe,
/// goes to the Home Screen and taps the app's icon twice, then opens one of
/// the app's own links (as a widget does). The app logs its connected scenes
/// each time a window comes forward; the script reads that log.
///
/// With TEST_RUNNER_SCENE_NEW_WINDOW the app also runs "Open in New Window"
/// once after launch.
final class SceneRelaunchDriver: XCTestCase {
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    func testRelaunchFromHomeScreen() {
        let app = XCUIApplication(bundleIdentifier: "org.elabx.fusionha.v2")
        app.launchEnvironment = ["FUSIONHA_SCENE_PROBE": "1"]
        if ProcessInfo.processInfo.environment["SCENE_NEW_WINDOW"] != nil {
            app.launchEnvironment["FUSIONHA_SCENE_PROBE_NEW_WINDOW"] = "1"
        }
        app.launch()
        sleep(16)
        for round in 1...2 {
            XCUIDevice.shared.press(.home)
            sleep(3)
            print("SCENES tap icon \(round): \(tapIcon("fusionha v2"))")
            sleep(8)
        }
        XCUIDevice.shared.press(.home)
        sleep(3)
        XCUIDevice.shared.system.open(URL(string: "fusionha2://library")!)
        let open = springboard.alerts.buttons["Open"]
        if open.waitForExistence(timeout: 5) { open.tap() }
        sleep(8)
        print("SCENES DONE")
    }

    /// Taps the app's Home Screen icon, paging through the Home Screen to find it.
    private func tapIcon(_ name: String) -> Bool {
        let icon = springboard.icons[name]
        for _ in 0..<6 {
            if icon.exists && icon.isHittable {
                icon.tap()
                return true
            }
            springboard.swipeLeft()
            sleep(1)
        }
        return false
    }
}
