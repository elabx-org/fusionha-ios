import XCTest

/// CI helper, not a test of the app: drives the held-download flow to states
/// no launch flag reaches (a SwiftUI `Menu` or context menu open, a bulk
/// Import answered) so scripts/held_flow_shot.sh can screenshot them.
///
/// Inputs (the script passes them as TEST_RUNNER_<name>):
/// - HELD_SHOT_ENV: the app's launch environment, `KEY=VALUE` pairs split by `;`.
/// - HELD_SHOT_STEPS: `;`-split steps: `press-bar` (long-press the downloads
///   bar for its menu), `tap:<label prefix>` (tap the first element whose label
///   starts so), `tapid:<accessibility identifier>`, `wait:<seconds>`.
/// - HELD_SHOT_EXPECT: a label prefix that proves the state is on screen.
/// Prints SHOT READY (or SHOT READY (expected element not found)) and holds.
final class HeldFlowOpener: XCTestCase {
    func testHeldFlowState() throws {
        let env = ProcessInfo.processInfo.environment
        let app = XCUIApplication(bundleIdentifier: "org.elabx.fusionha")
        var launch: [String: String] = [:]
        for pair in (env["HELD_SHOT_ENV"] ?? "").split(separator: ";") {
            let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if kv.count == 2 { launch[kv[0]] = kv[1] }
        }
        app.launchEnvironment = launch
        app.launch()
        sleep(10)
        for step in (env["HELD_SHOT_STEPS"] ?? "").split(separator: ";").map(String.init) {
            if step == "press-bar" {
                let bar = element(app, prefix: "Downloads,")
                if bar.waitForExistence(timeout: 20) {
                    bar.press(forDuration: 1.2)
                } else {
                    print("bar not found; pressing above the tab bar")
                    app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.86)).press(forDuration: 1.2)
                }
            } else if step.hasPrefix("tapid:") {
                let id = String(step.dropFirst(6))
                let target = app.descendants(matching: .any).matching(identifier: id).firstMatch
                if target.waitForExistence(timeout: 20) { target.tap() } else { print("not found: \(step)") }
            } else if step.hasPrefix("tap:") {
                let target = element(app, prefix: String(step.dropFirst(4)))
                if target.waitForExistence(timeout: 20) { target.tap() } else { print("not found: \(step)") }
            } else if step.hasPrefix("wait:") {
                sleep(UInt32(step.dropFirst(5)) ?? 1)
            }
            sleep(1)
        }
        let expect = env["HELD_SHOT_EXPECT"] ?? ""
        let found = expect.isEmpty || element(app, prefix: expect).waitForExistence(timeout: 10)
        print(found ? "SHOT READY" : "SHOT READY (expected element not found)")
        sleep(25)
    }

    private func element(_ app: XCUIApplication, prefix: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }
}
