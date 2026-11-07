import SwiftUI

/// How Coming up looks on the open Duo (owner-approved mock "Coming up as
/// the hero", 2026-11-07): Posters (A, the default) keeps the 2:3 posters,
/// only bigger; Backdrops (B) shows the 16:9 backdrop art. Folded and the
/// phone always show posters. Kept on this device under `key`.
enum V2ComingUpWideStyle: String, CaseIterable, Identifiable {
    case posters, backdrops

    static let key = "v2.home.comingUpWide"

    var id: Self { self }

    var title: String {
        switch self {
        case .posters: return "Posters"
        case .backdrops: return "Backdrops"
        }
    }

    /// The stored value (an unknown one is Posters). CI screenshots:
    /// `FUSIONHA_SCREENSHOT_HOME_WIDE=backdrops` overrides it.
    init(stored: String) {
        #if DEBUG
        if let shot = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_HOME_WIDE"],
           let style = Self(rawValue: shot) {
            self = style
            return
        }
        #endif
        self = Self(rawValue: stored) ?? .posters
    }
}

/// Settings › Appearance (v2 only): the same switch as the Coming up menu's
/// "Open Duo" section.
struct V2ComingUpWideSection: View {
    @AppStorage(V2ComingUpWideStyle.key) private var raw = V2ComingUpWideStyle.posters.rawValue

    var body: some View {
        SettingsSection("Home on the open iPhone Duo",
                        footer: "Only this iPhone. Posters keeps Coming up's posters, bigger, with two on each side. Backdrops shows each title's landscape art, wide across the page. Folded, Coming up always shows posters.") {
            Picker("Coming up", selection: $raw) {
                ForEach(V2ComingUpWideStyle.allCases) { Text($0.title).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
        }
        .settingsField("Home on the open iPhone Duo")
    }
}
