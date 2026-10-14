import SwiftUI

/// This iPhone's Live Activity choices (Account › Live Activity), stored on
/// the phone. Today the activity has one state, downloads; the per-kind
/// switches arrive with the Live Activity redesign.
enum LiveActivityPrefs {
    static let enabledKey = "liveActivity.enabled"

    static var enabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }
}

/// Account › Live Activity.
struct LiveActivityPrefsView: View {
    @AppStorage(LiveActivityPrefs.enabledKey) private var enabled = true

    var body: some View {
        List {
            Section {
                Toggle("Show on Lock Screen", isOn: $enabled)
                    .tint(Theme.done)
                    .onChange(of: enabled) { _, on in if !on { LiveActivityController.endAll() } }
            } footer: {
                Text("Downloads show on the Lock Screen and in the Dynamic Island while the app is running. iOS's own switch is in the iPhone's Settings › fusionha › Live Activities.")
            }
            .listRowBackground(AccountStyle.cell)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Live Activity")
        .navigationBarTitleDisplayMode(.inline)
    }
}
