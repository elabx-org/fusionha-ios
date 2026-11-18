import Foundation

/// Design options rendered for the owner's real-app mocks (DEBUG only): set
/// `FUSIONHA_MOCK_<NAME>` at launch to draw an option a change would bring,
/// so it can be screenshotted beside today's. Release builds see none.
/// None are in use: each is removed once its option is chosen.
enum MockFlag {
    static func value(_ name: String) -> String? {
        #if DEBUG
        return ProcessInfo.processInfo.environment["FUSIONHA_MOCK_\(name)"]
        #else
        return nil
        #endif
    }
}
