import SwiftUI
import FusionhaKit

/// This iPhone's Live Activity choices (Account › Live Activity), stored on
/// the phone: whether it shows at all, which downloads count towards it (by
/// how they were grabbed, by version, and whether ones waiting on you keep
/// it open), and how long the finished summary stays on the Lock Screen.
enum LiveActivityPrefs {
    static let enabledKey = "liveActivity.enabled"
    static let newGrabsKey = "liveActivity.newGrabs"
    static let upgradesKey = "liveActivity.upgrades"
    static let regrabsKey = "liveActivity.regrabs"
    static let hdKey = "liveActivity.hd"
    static let uhdKey = "liveActivity.uhd"
    static let waitingKey = "liveActivity.waitingOnYou"
    static let lingerKey = "liveActivity.finishedMinutes"

    private static func flag(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    static var enabled: Bool { flag(enabledKey) }

    /// Minutes the "All done" summary stays after the last download ends.
    static var lingerMinutes: Int {
        UserDefaults.standard.object(forKey: lingerKey) as? Int ?? 15
    }

    /// Whether this download counts towards the Live Activity.
    static func includes(_ item: QueueItem) -> Bool {
        switch item.tier {
        case .hd: if !flag(hdKey) { return false }
        case .uhd: if !flag(uhdKey) { return false }
        }
        let status = item.status.lowercased()
        if (status == "held" || item.needsAttention == true) && !flag(waitingKey) { return false }
        switch item.grabTrigger?.lowercased() {
        case "upgrade": return flag(upgradesKey)
        case "regrab": return flag(regrabsKey)
        default: return flag(newGrabsKey)
        }
    }
}

/// Account › Live Activity.
struct LiveActivityPrefsView: View {
    @AppStorage(LiveActivityPrefs.enabledKey) private var enabled = true
    @AppStorage(LiveActivityPrefs.newGrabsKey) private var newGrabs = true
    @AppStorage(LiveActivityPrefs.upgradesKey) private var upgrades = true
    @AppStorage(LiveActivityPrefs.regrabsKey) private var regrabs = true
    @AppStorage(LiveActivityPrefs.hdKey) private var hd = true
    @AppStorage(LiveActivityPrefs.uhdKey) private var uhd = true
    @AppStorage(LiveActivityPrefs.waitingKey) private var waiting = true
    @AppStorage(LiveActivityPrefs.lingerKey) private var linger = 15

    var body: some View {
        List {
            Section {
                Toggle("Show on Lock Screen", isOn: $enabled)
                    .onChange(of: enabled) { _, on in if !on { LiveActivityController.endAll() } }
            } footer: {
                Text("Downloads show on the Lock Screen and in the Dynamic Island while the app is running. iOS's own switch is in Settings › fusionha › Live Activities.")
            }
            .listRowBackground(AccountStyle.cell)

            if enabled {
                Section {
                    Toggle("New grabs", isOn: $newGrabs)
                    Toggle("Upgrades", isOn: $upgrades)
                    Toggle("Re-grabs", isOn: $regrabs)
                } header: {
                    Text("Downloads that count")
                } footer: {
                    Text("New grabs come from RSS, searches and requests. Upgrades replace a copy you already have.")
                }
                .listRowBackground(AccountStyle.cell)

                Section("Versions") {
                    Toggle("HD", isOn: $hd)
                    Toggle("4K", isOn: $uhd)
                }
                .listRowBackground(AccountStyle.cell)

                Section {
                    Toggle("Downloads waiting on you", isOn: $waiting)
                    Picker("Keep “All done” for", selection: $linger) {
                        Text("Don't keep").tag(0)
                        Text("5 minutes").tag(5)
                        Text("15 minutes").tag(15)
                        Text("1 hour").tag(60)
                    }
                } header: {
                    Text("Lock Screen")
                } footer: {
                    Text("Held or stuck downloads keep the Live Activity open until you deal with them. Turn this off to show only downloads that are moving.")
                }
                .listRowBackground(AccountStyle.cell)

                Section {
                    ForEach(LiveActivityPosters.diagnostics(ids: LiveActivityController.itemIds), id: \.self) { line in
                        Text(line).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.mut)
                            .textSelection(.enabled)
                    }
                } header: {
                    Text("Poster check")
                } footer: {
                    Text("Where each poster was saved and what the Lock Screen found. A screenshot of this helps if posters stay blank.")
                }
                .listRowBackground(AccountStyle.cell)
            }
        }
        .tint(Theme.done)
        .scrollContentBackground(.hidden)
        .navigationTitle("Live Activity")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: [newGrabs, upgrades, regrabs, hd, uhd, waiting]) { LiveActivityController.resync() }
    }
}
