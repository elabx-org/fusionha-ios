import XCTest

/// CI helper, not a test of the app. `simctl openurl` makes the simulator ask
/// "Open in “fusionha”?" (a widget tap on a phone never does), which would
/// stop every deep-link check at the prompt. Run in the background by
/// scripts/deeplink_check.sh, this taps Open whenever the prompt shows, for a
/// few minutes, so the links reach the app the way a widget tap delivers them.
final class OpenPromptAcceptor: XCTestCase {
    func testAcceptOpenPrompts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let end = Date().addingTimeInterval(300)
        print("ACCEPTOR READY")
        while Date() < end {
            let open = springboard.alerts.buttons["Open"]
            if open.waitForExistence(timeout: 1) {
                open.tap()
                print("ACCEPTOR tapped Open")
            }
        }
    }
}
