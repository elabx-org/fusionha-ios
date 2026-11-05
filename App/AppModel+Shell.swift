import Foundation
import FusionhaKit

extension AppModel {
    // MARK: Shell settings (the polling lives in AppSession+Polling)

    /// Admins pick the library's coverage-rail display (`PUT /api/v1/settings`).
    func updateRails(style: RailStyle? = nil, consolidate: Bool? = nil) async {
        guard let client else { return }
        do {
            try await client.updateRailSettings(RailSettingsUpdate(libraryRailStyle: style?.rawValue,
                                                                   libraryRailConsolidate: consolidate))
            await shell.reloadSettings(client: client)
        } catch {
            toast("Couldn't save the rail setting", variant: .error)
        }
    }

    /// The Library scroll hides the chrome scrolling down and shows it
    /// scrolling up or near the top (`offset` from the top of the content).
    func updateChrome(old: CGFloat, new: CGFloat) {
        let delta = new - old
        if new <= 90 {
            if chromeHidden { chromeHidden = false }
        } else if delta > 4 {
            if !chromeHidden { chromeHidden = true }
        } else if delta < -4 {
            if chromeHidden { chromeHidden = false }
        }
    }
}
