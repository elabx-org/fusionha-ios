import SwiftUI
import FusionhaKit

/// The downloads bar on the iPhone Duo where the system's can't show (plan
/// S8/S14): in book pose the tabs' column crosses the fold, so the tab bar's
/// accessory stays away; this floats on the left page instead, the same
/// content as `V2DownloadsAccessory` on a glass capsule. `RootView` places it
/// and decides when (queue has items, off Activity, no bulk bar).
struct DuoDownloadsCapsule: View {
    let state: DownloadsBarState

    var body: some View {
        V2DownloadsAccessory(state: state, publishesFrame: false)
            .frame(height: 52)
            .glassEffect(.regular.interactive(), in: Capsule())
    }
}
